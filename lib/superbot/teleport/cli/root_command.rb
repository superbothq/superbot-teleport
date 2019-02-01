# frozen_string_literal: true

require_relative 'validations'

module Superbot
  module Teleport
    module CLI
      class RootCommand < Clamp::Command
        include Superbot::Teleport::Validations

        option ['-v', '--version'], :flag, "Show version information" do
          puts Superbot::Teleport::VERSION
          exit 0
        end

        option ['--browser'], 'BROWSER', "Browser type to use. Can be either local or cloud", default: 'cloud'
        option ['--region'], 'REGION', 'Region for remote webdriver'
        option ['--org'], 'ORGANIZATION', 'Name of organization to take action', attribute_name: :organization
        option ['--reuse'], :flag, "Reuse existing session"

        def execute
          validate_teleport_options(browser, organization)

          run_local_chromedriver if browser == 'local'

          puts 'Opening teleport...', ''
          puts 'Configure your remote webdriver to http://localhost:4567/wd/hub', ''
          puts 'Press [control+c] to exit', ''

          @web = Superbot::Web.run!(
            webdriver_type: browser,
            region: region,
            organization: organization,
            reuse: reuse?
          )

          at_exit do
            @web&.quit!
          end
        end

        def run_local_chromedriver
          chromedriver_path = Chromedriver::Helper.new.binary_path
          @chromedriver = Kommando.run_async "#{chromedriver_path} --silent --port=9515 --url-base=wd/hub"

          at_exit do
            @chromedriver&.kill
          end
        end
      end
    end
  end
end
