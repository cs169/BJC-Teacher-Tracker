# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Ruby 3.3 no longer autoloads Logger, but Rails 6.1's ActiveSupport requires
# it during boot. Load it here so every entrypoint (rake, rails, cucumber,
# rspec) picks it up before ActiveSupport is required.
require "logger"
