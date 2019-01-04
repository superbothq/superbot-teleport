
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "superbot/teleport/version"

Gem::Specification.new do |spec|
  spec.name          = "superbot-teleport"
  spec.version       = Superbot::Teleport::VERSION
  spec.authors       = ["Superbot HQ"]

  spec.summary       = "superbot-teleport"
  spec.homepage      = "https://github.com/superbothq/superbot-teleport"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "excon"

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 11.2"
  spec.add_development_dependency "rspec", "~> 3.8"
  spec.add_development_dependency "pry"

  spec.add_development_dependency "superbot", "~> 0.2.2"
  spec.add_development_dependency "superbot-selenium-webdriver", "~> 1.0.1"
end
