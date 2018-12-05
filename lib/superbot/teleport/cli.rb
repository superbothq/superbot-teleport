require 'sinatra/base'
require 'excon'
require 'json'

module Superbot
  module Teleport
    class CLI
      def start!
        s = Sinatra.new
        s.set :raise_errors, false
        s.set :show_exceptions, false

        s.before do
          $__superbot_teleport_request_for_errors = request
        end

        s.set :connection, (
          Excon.new ENV.fetch("SUPERBOT_TELEPORT_UPSTREAM_URL"), {
            persistent: true,
            connect_timeout: 3,
            read_timeout: 5,
            write_timeout: 5,
            debug_request: (ENV["EXCON_DEBUG"] == "true"),
            debug_response: (ENV["EXCON_DEBUG"] == "true")
          }
        )

        s.helpers do
          def request_path(params)
            params[:splat].join("/")
          end

          def safe_parse_json(string_or_io, on_error: nil)
            JSON.parse (string_or_io.respond_to?(:read) ? string_or_io.read : string_or_io)
          rescue
            on_error
          end

          def proxy(method, params, opts={})
            raise "DELETE may not contain body" if method == :delete && opts[:body]
            opts[:headers] ||= {}

            unless ENV.fetch("SUPERBOT_TELEPORT_UPSTREAM_URL").include? "localhost"
              path = "wd/hub/#{request_path(params)}"
              headers["Content-Type"] = "application/json"
            else
              path = request_path
            end

            settings.connection.request({method: method, path: path}.merge(opts))
          end

          def respond(upstream)
            headers = upstream.headers
            status upstream.status
            upstream.body
          end
        end

        s.get "/wd/hub/*" do
          respond proxy(:get, params, {headers: headers, body: request.body})
        end

        s.post "/wd/hub/*" do
          case request_path(params)
          when "session"
            parsed_body = safe_parse_json request.body, on_error: {}

            if ENV['SUPERBOT_TELEPORT_REGION'] && parsed_body['desiredCapabilities']
              parsed_body['desiredCapabilities']['superOptions'] = { "region": ENV['SUPERBOT_TELEPORT_REGION'] }
            end

            respond proxy(:post, params, {headers: headers, body: parsed_body.to_json, read_timeout: 500})
          else
            respond proxy(:post, params, {headers: headers, body: request.body})
          end
        end

        s.delete "/wd/hub/*" do
          respond proxy(:delete, params, {headers: headers})
        end

        s.error Excon::Error::Socket do
          puts "="*30
          puts $__superbot_teleport_request_for_errors.path_info

          if $!.message.end_with? "(Errno::ECONNREFUSED)"
            status 500
            "upstream does not respond"
          else
            raise "unknown: #{$!.message}"
          end
        end

        s.run!
      end
    end
  end
end
