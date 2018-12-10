require_relative "teleport/version"
require_relative "teleport/web"
require_relative "teleport/cli"

module Superbot
  module Teleport
    class Error < StandardError; end
  end
end
