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
        option ['--region'], 'REGION', "Region for remote webdriver"
        option ['--org'], "ORGANIZATION", "Name of organization to take action on", environment_variable: "SUPERBOT_ORG", attribute_name: :organization, default: Superbot::Cloud.credentials&.fetch(:organization, nil)

        option ['--ignore-delete'], :flag, "Reuse existing session"
        option ['--keep-session'], :flag, "Keep session after teleport is closed"
        option ['--session'], 'SESSION', "Session to use in teleport"
        option ['--base-url'], 'BASE_URL', "Base project URL"
        option ['--source'], 'SOURCE', "Source deployment for webdriver session", environment_variable: "SUPERBOT_SOURCE"

        def execute
          validate_teleport_options(browser, organization, session)

          run_local_chromedriver if browser == 'local'

          puts 'Opening teleport...', ''
          puts 'Configure your remote webdriver to http://localhost:4567/wd/hub', ''
          puts 'Press [control+c] to exit', ''

          @web = Superbot::Web.run!(
            webdriver_type: browser,
            region: region,
            organization: organization,
            ignore_delete: session || ignore_delete?,
            keep_session: session || keep_session?,
            session: session,
            base_url: base_url,
            source: source
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
