# Entry point for the bug_reports_client gem. Hosts configure the engine in an
# initializer via BugReportsClient.configure and mount BugReportsClient::Engine
# in their routes. See README.md for the full setup guide.
require "bug_reports_client/version"
require "bug_reports_client/configuration"
require "bug_reports_client/form_schema"
require "bug_reports_client/main_app_routes"
require "bug_reports_client/error_reporter"
require "bug_reports_client/error_context"
require "bug_reports_client/engine"

module BugReportsClient
  # Raised when the gem is misconfigured (missing source, API key, etc).
  class ConfigurationError < StandardError; end

  # Raised when a host's form schema file is invalid.
  class SchemaError < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config)
    end

    # Replaces the configuration entirely. Used by tests to reset state.
    def reset_config!
      @config = Configuration.new
      FormSchema.reset!
    end

    # The active form schema (host override or the engine default).
    def form_schema
      FormSchema.current
    end
  end
end
