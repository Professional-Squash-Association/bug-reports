# Boots the dummy host app and loads the engine test support. The dummy app
# mirrors a real host: session auth, a User model including Reporter, and a
# layout that renders bug_report_alerts.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "webmock/minitest"

# Build the dummy database fresh for each run.
load File.expand_path("dummy/db/schema.rb", __dir__)

module BugReportsClient
  module TestConfig
    API_URL = "https://bugs.example.test/api".freeze

    # Baseline engine configuration used by most tests. Individual tests
    # tweak BugReportsClient.config directly; setup re-applies the baseline.
    def apply_test_config!
      BugReportsClient.reset_config!
      BugReportsClient.configure do |config|
        config.source = "dummy"
        config.api_url = API_URL
        config.api_key = "test-api-key"
        config.webhook_secret = "test-webhook-secret"
        config.app_host = "https://dummy.example.test"
        config.admin_check = ->(user) { user.respond_to?(:admin) && user.admin? }
      end
    end
  end
end

class ActiveSupport::TestCase
  include BugReportsClient::TestConfig

  # File fixtures live with the engine's tests, not the dummy app.
  self.file_fixture_path = File.expand_path("fixtures/files", __dir__)

  # Sequential runs: the suite shares one SQLite file and engine config state.
  parallelize(workers: 1)

  setup do
    apply_test_config!
  end

  teardown do
    BugReportsClient.reset_config!
  end

  def create_user(email: "reporter@example.test", name: "Test Reporter", admin: false)
    User.create!(email: email, name: name, admin: admin)
  end

  def create_bug_report(user:, **attributes)
    BugReportsClient::BugReport.create!({
      user: user,
      title: "Something is broken",
      report_type: "bug",
      severity: "medium",
      responses: {
        "impact" => "Everyone is affected",
        "expected_behaviour" => "It should work",
        "actual_behaviour" => "It does not work"
      }
    }.merge(attributes))
  end
end

class ActionDispatch::IntegrationTest
  # Signs the given user into the dummy app's session.
  def sign_in(user)
    post "/test_session", params: { user_id: user.id }
  end
end
