# frozen_string_literal: true

require "superbot/cloud/cli/cloud/validations"

module Superbot
  module CLI
    class TeleportCommand < Clamp::Command
      include Superbot::Validations
      include Superbot::Cloud::Validations

      option ['-v', '--version'], :flag, "Show version information" do
        puts Superbot::Teleport::VERSION
        exit 0
      end

      option ['--browser'], 'BROWSER', "Browser type to use. Can be either local or cloud", default: 'cloud' do |browser|
        validates_browser_type browser
      end
      option ['--region'], 'REGION', 'Region for remote webdriver'

      def execute
        require_login unless browser == 'local'

        puts "Opening teleport...", ''
        puts 'Configure your remote webdriver to http://localhost:4567/wd/hub', ''
        puts 'Press [control+c] to exit', ''
        @web = Superbot::Web.new
        @web.register(Superbot::Teleport::Web, webdriver_type: browser, region: region)

        @web.run!
      ensure
        close_teleport
      end

      def close_teleport
        @chromedriver&.kill
        @web&.quit!
      end
    end
  end
end
