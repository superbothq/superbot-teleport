require 'excon'
require 'json'

module Superbot
  module Teleport
    module Web
      def self.registered(sinatra)
        sinatra.before do
          $__superbot_teleport_request_for_errors = request
        end

        auth_header = format(
          '%<auth_type>s %<auth_token>s',
          auth_type: ENV['SUPERBOT_TOKEN'] ? 'Bearer' : 'Basic',
          auth_token: Base64.urlsafe_encode64(
            ENV.fetch(
              'SUPERBOT_TOKEN',
              Superbot::Cloud.credentials&.values_at(:username, :token)&.join(':').to_s
            )
          )
        )

        sinatra.set :connection, Excon.new(
          sinatra.webdriver_url,
          persistent: true,
          headers: { 'Authorization' => auth_header, 'Content-Type' => 'application/json' },
          connect_timeout: 3,
          read_timeout: 500,
          write_timeout: 500
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
            path = "wd/hub/#{request_path(params)}"
            headers["Content-Type"] = "application/json"

            settings.connection.request({ method: method, path: path }.merge(opts))
          end

          def respond(upstream)
            headers upstream.headers
            status upstream.status
            upstream.body
          end
        end

        sinatra.get "/wd/hub/*" do
          respond proxy(:get, params, headers: headers, body: request.body)
        end

        sinatra.post "/wd/hub/*" do
          case request_path(params)
          when "session"
            if settings.teleport_options[:session]
              status 200
              headers 'Content-Type' => 'application/json'
              return { 'sessionId': settings.teleport_options[:session] }.to_json
            else
              parsed_body = safe_parse_json request.body, on_error: {}

              parsed_body['organization_name'] = settings.teleport_options[:organization]

              if settings.teleport_options[:region] && parsed_body.dig('desiredCapabilities', 'superOptions', 'region').nil?
                parsed_body['desiredCapabilities'] ||= {}
                parsed_body['desiredCapabilities']['superOptions'] ||= {}
                parsed_body['desiredCapabilities']['superOptions']['region'] ||= settings.teleport_options[:region]
              end

              session_response = proxy(
                :post,
                params,
                headers: headers,
                body: parsed_body.to_json,
                write_timeout: 500,
                read_timeout: 500
              )
              settings.teleport_options[:session] = JSON.parse(session_response.body)['sessionId']

              respond session_response
            end
          else
            respond proxy(:post, params, headers: headers, body: request.body)
          end
        end

        sinatra.delete "/wd/hub/*" do
          if settings.teleport_options[:ignore_delete]
            puts "Skipping DELETE, keep session open"
            halt 204
          else
            settings.teleport_options[:session] = nil
            respond proxy(:delete, params, headers: headers)
          end
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

        at_exit do
          return if sinatra.teleport_options[:session] && sinatra.settings.teleport_options[:keep_session]

          puts nil, "Removing active session..."
          sinatra.settings.connection.request(
            method: :delete,
            path: "wd/hub/session/#{sinatra.teleport_options[:session]}",
            headers: { 'Content-Type' => 'application/json' }
          )
        rescue => e
          puts e.message
        end
      end
    end
  end
end
