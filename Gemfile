source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in superbot-teleport.gemspec
gemspec

unless ENV['SUPERBOT_USE_RUBYGEMS'] == "yes"
  gem "superbot", path: "../superbot"
  gem "superbot-cloud", path: "../superbot-cloud"
end
