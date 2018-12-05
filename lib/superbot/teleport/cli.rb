require 'sinatra'
require 'excon'

module Superbot
  module Teleport
    class CLI
      def start!
        s = Sinatra.new
        s.set :raise_errors, false
        s.set :show_exceptions, false

        s.before do
          $__request = request
        end

        s.error Excon::Error::Socket do
          puts "="*30
          puts $__request.path_info

          if $!.message.end_with? "(Errno::ECONNREFUSED)"
            status 500
            "upstream failed"
          else
            raise "unknown"
          end
        end

        s.set :connection, (
          Excon.new ENV.fetch("SUPERBOT_TELEPORT_UPSTREAM_URL"), {
            persistent: true,
            connect_timeout: 5,
            read_timeout: 5,
            write_timeout: 5,
            debug_request: (ENV["EXCON_DEBUG"] == "true"),
            debug_response: (ENV["EXCON_DEBUG"] == "true")
          }
        )

        [:get, :post, :delete].each do |method|
          s.send method, "/wd/hub/*" do
            path = params[:splat].join("/")

            unless ENV.fetch("SUPERBOT_TELEPORT_UPSTREAM_URL").include? "localhost"
              path = "wd/hub/#{path}"
              headers["Content-Type"] = "application/json"
            end

            upstream = settings.connection.request({
              method: method, path: path, body: request.body, headers: headers
            })

            headers = upstream.headers
            status upstream.status
            upstream.body
          end
        end

        s.run!
      end
    end
  end
end
