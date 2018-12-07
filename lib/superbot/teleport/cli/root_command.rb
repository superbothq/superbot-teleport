# frozen_string_literal: true

require_relative 'teleport_command'

module Superbot
  module CLI
    class RootCommand < Clamp::Command
      subcommand ['teleport'], "Open teleport to the cloud", TeleportCommand
    end
  end
end
