require 'excon'
require 'json'

module Superbot
  module Teleport
    module Web
      def self.register(sinatra, webdriver_type: 'cloud', region: nil)
        sinatra.before do
          $__superbot_teleport_request_for_errors = request
        end

        user_auth_creds = Superbot::Cloud.credentials&.slice(:username, :token) || {}

        sinatra.set :webdriver_type, webdriver_type
        sinatra.set :webdriver_url, Superbot.webdriver_endpoint(webdriver_type)
        sinatra.set :region, region

        sinatra.set :connection, (
          Excon.new sinatra.webdriver_url, {
            user: user_auth_creds[:username],
            password: user_auth_creds[:token],
            persistent: true,
            connect_timeout: 3,
            read_timeout: 5,
            write_timeout: 5,
          }
        )

        sinatra.helpers do
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

            unless settings.webdriver_type == 'local'
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

        sinatra.get "/wd/hub/*" do
          respond proxy(:get, params, {headers: headers, body: request.body})
        end

        sinatra.post "/wd/hub/*" do
          case request_path(params)
          when "session"
            parsed_body = safe_parse_json request.body, on_error: {}

            if settings.region && parsed_body.dig('desiredCapabilities', 'superOptions', 'region').nil?
              parsed_body['desiredCapabilities'] ||= {}
              parsed_body['desiredCapabilities']['superOptions'] ||= {}
              parsed_body['desiredCapabilities']['superOptions']['region'] ||= settings.region
            end

            respond proxy(:post, params, {headers: headers, body: parsed_body.to_json, read_timeout: 500})
          else
            respond proxy(:post, params, {headers: headers, body: request.body})
          end
        end

        sinatra.delete "/wd/hub/*" do
          respond proxy(:delete, params, {headers: headers})
        end

        sinatra.error Excon::Error::Socket do
          puts "="*30
          puts $__superbot_teleport_request_for_errors.path_info

          if $!.message.end_with? "(Errno::ECONNREFUSED)"
            status 500
            "upstream does not respond"
          else
            raise "unknown: #{$!.message}"
          end
        end
      end
    end
  end
end
