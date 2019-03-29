require 'excon'
require 'json'

module Superbot
  module Teleport
    module Web
      def self.registered(sinatra)
        sinatra.before do
          $__superbot_teleport_request_for_errors = request
        end

        sinatra.set :connection, Excon.new(
          sinatra.webdriver_url,
          persistent: true,
          headers: { 'Authorization' => Superbot::Cloud.authorization_header },
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

            settings.connection.request({ method: method, path: path, idempotent: true }.merge(opts))
          end

          def respond(upstream)
            headers upstream.headers
            status upstream.status
            upstream.body
          end

          def acquire_session(parsed_body: {}, headers: {})
            assign_super_options(parsed_body)
            proxy(
              :post,
              { splat: ['session'] },
              headers: headers.merge('Idempotency-Key' => SecureRandom.hex),
              body: parsed_body.to_json,
              retry_interval: 60
            ).tap do |session_response|
              parsed_response = safe_parse_json session_response.body, on_error: {}
              settings.teleport_options[:session] = parsed_response['sessionId']
            end
          end

          def assign_super_options(parsed_body)
            parsed_body['organization_name'] = settings.teleport_options[:organization]

            if settings.teleport_options.slice(:region, :tag).compact.any?
              parsed_body['desiredCapabilities'] ||= { 'browserName' => 'chrome', 'pageLoadStrategy' => 'eager' }
              parsed_body['desiredCapabilities']['superOptions'] ||= {}
              parsed_body['desiredCapabilities']['superOptions']['region'] ||= settings.teleport_options[:region]
              parsed_body['desiredCapabilities']['superOptions']['tag'] ||= settings.teleport_options[:tag]
            end
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
              respond acquire_session(parsed_body: parsed_body, headers: headers)
            end
          else
            parsed_body = safe_parse_json request.body, on_error: {}

            if settings.teleport_options[:base_url] && parsed_body['url']
              parsed_body['url'] = URI.join(
                settings.teleport_options[:base_url],
                URI(parsed_body['url']).path.to_s
              ).to_s
            end

            respond proxy(:post, params, headers: headers, body: parsed_body.to_json)
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

        if sinatra.teleport_options[:acquire_session]
          sinatra.connection.request(
            method: :post,
            path: 'wd/hub/session',
            headers: { 'Content-Type' => 'application/json', 'Idempotency-Key' => SecureRandom.hex },
            body: {
              organization_name: sinatra.teleport_options[:organization],
              desiredCapabilities: {
                browserName: 'chrome',
                pageLoadStrategy: 'eager',
                superOptions: {
                  tag: sinatra.teleport_options[:tag],
                  region: sinatra.teleport_options[:region],
                }.compact
              }
            }.to_json,
            idempotent: true,
            retry_interval: 60
          ).tap do |session_response|
            if session_response.status == 200
              sinatra.teleport_options[:session] = JSON.parse(session_response.body)['sessionId']
            end
          end
        end

        at_exit do
          return if sinatra.teleport_options[:session].nil? || sinatra.teleport_options[:keep_session]

          puts nil, "Removing active session..."
          sinatra.connection.request(
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
