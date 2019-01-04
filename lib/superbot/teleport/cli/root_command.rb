# frozen_string_literal: true

module Superbot
  module Teleport
    module CLI
      class RootCommand < Clamp::Command
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
        option ['--org'], 'ORGANIZATION', 'Name of organization to take action', attribute_name: :organization

        def execute
          require_login unless browser == 'local'

          puts 'Opening teleport...', ''
          puts 'Configure your remote webdriver to http://localhost:4567/wd/hub', ''
          puts 'Press [control+c] to exit', ''

          if browser == 'local'
            chromedriver_path = Chromedriver::Helper.new.binary_path
            @chromedriver = Kommando.run_async "#{chromedriver_path} --silent --port=9515 --url-base=wd/hub"
          end

          @web = Superbot::Web.run!(webdriver_type: browser, region: region, organization: organization)
        ensure
          close_teleport
        end

        def close_teleport
          @web&.quit!
          @chromedriver&.kill
        end
      end
    end
  end
end
