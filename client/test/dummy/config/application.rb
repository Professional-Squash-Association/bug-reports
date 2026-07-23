# Minimal host app used by the engine's test suite. Mirrors what a real host
# provides: a User model, session-based current_user/authenticate_user!, an
# application layout that renders bug_report_alerts, and Active Storage.
require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "turbo-rails"

require "bug_reports_client"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.consider_all_requests_local = true
    config.active_storage.service = :test
    # The test helper loads db/schema.rb directly; skip the pending-migration
    # check (the engine's own migration is exercised by real hosts).
    config.active_record.maintain_test_schema = false
    config.action_controller.allow_forgery_protection = false
    config.secret_key_base = "dummy-secret-key-base-for-tests"
    config.hosts.clear
    config.logger = Logger.new(File::NULL)
  end
end
