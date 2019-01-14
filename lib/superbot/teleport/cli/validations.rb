# frozen_string_literal: true

module Superbot
  module Teleport
    module Validations
      include Superbot::Cloud::Validations

      def validate_teleport_options(browser, organization)
        return if browser == 'local'

        unless %w[local cloud local_cloud].include?(browser)
          signal_usage_error "The --browser=#{browser} browser option is not allowed. Should be either 'local' or 'cloud'."
        end

        signal_usage_error '--org option is required for cloud teleport' unless organization

        require_login
      end
    end
  end
end
