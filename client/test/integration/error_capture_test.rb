require "test_helper"

module BugReportsClient
  # Automatic 500 capture: subscriber filtering, fingerprint stability,
  # throttling, and the report job's API submission.
  class ErrorCaptureTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    ERROR_ENDPOINT = "#{BugReportsClient::TestConfig::API_URL}/error_reports".freeze

    setup do
      BugReportsClient.config.error_reporting_enabled = true
      # A real cache store so the throttle is exercised (test default is
      # null) - fresh per test so one test's claims can't throttle another.
      Rails.instance_variable_set(:@brc_test_cache, ActiveSupport::Cache::MemoryStore.new)
      Rails.singleton_class.send(:alias_method, :original_cache, :cache)
      Rails.define_singleton_method(:cache) { @brc_test_cache }
    end

    teardown do
      Rails.singleton_class.send(:remove_method, :cache)
      Rails.singleton_class.send(:alias_method, :cache, :original_cache)
      Rails.singleton_class.send(:remove_method, :original_cache)
      clear_enqueued_jobs
    end

    test "an unhandled 500 enqueues an error report" do
      get "/boom"
      assert_response :internal_server_error

      assert_enqueued_with(job: ReportErrorJob)
      payload = enqueued_jobs.last[:args].first
      assert_equal "ArgumentError", payload["exception_class"]
      assert_match(/boom from dummy/, payload["message"])
      assert payload["fingerprint"].present?
      assert(payload["backtrace"].any? { |line| line.include?("home_controller") })
    end

    test "errors mapped to 4xx are ignored" do
      get "/missing"
      assert_response :not_found

      assert_no_enqueued_jobs(only: ReportErrorJob)
    end

    test "nothing is captured when disabled" do
      BugReportsClient.config.error_reporting_enabled = false

      get "/boom"
      assert_no_enqueued_jobs(only: ReportErrorJob)
    end

    test "host-configured ignore list is respected" do
      BugReportsClient.config.error_ignore = [ "ArgumentError" ]

      get "/boom"
      assert_no_enqueued_jobs(only: ReportErrorJob)
    end

    test "repeats within the throttle period are not re-enqueued" do
      get "/boom"
      get "/boom"

      assert_equal 1, enqueued_jobs.count { |job| job[:job] == ReportErrorJob }
    end

    test "fingerprints are stable across line shifts but distinct per error class" do
      error = ArgumentError.new("x")
      error.set_backtrace([ "#{Rails.root}/app/models/thing.rb:10:in `explode'" ])
      shifted = ArgumentError.new("different message")
      shifted.set_backtrace([ "#{Rails.root}/app/models/thing.rb:99:in `explode'" ])
      other_class = TypeError.new("x")
      other_class.set_backtrace([ "#{Rails.root}/app/models/thing.rb:10:in `explode'" ])

      assert_equal ErrorReporter.fingerprint_for(error), ErrorReporter.fingerprint_for(shifted)
      assert_not_equal ErrorReporter.fingerprint_for(error), ErrorReporter.fingerprint_for(other_class)
    end

    test "the report job posts the error to the API" do
      stub_request(:post, ERROR_ENDPOINT).to_return(status: 202, body: { id: 9, status: "queued" }.to_json)

      ReportErrorJob.perform_now(
        "fingerprint" => "abc123",
        "exception_class" => "ArgumentError",
        "message" => "boom",
        "backtrace" => [ "app/models/thing.rb:10:in `explode'" ],
        "occurred_at" => "2026-07-23T10:00:00Z"
      )

      assert_requested(:post, ERROR_ENDPOINT) do |request|
        body = JSON.parse(request.body)["error_report"]
        body["fingerprint"] == "abc123" &&
          body["source"] == "dummy" &&
          body["severity"] == "high" &&
          body["title"].start_with?("[Error] ArgumentError") &&
          body["description"].include?("app/models/thing.rb:10")
      end
    end

    test "a captured 500 is attributed to the signed-in user who hit it" do
      user = create_user
      sign_in user

      get "/boom"
      get "/boom" # second occurrence is throttled from posting but still recorded

      events = ErrorEvent.where(user_id: user.id)
      assert_equal 2, events.count
      assert_equal "ArgumentError", events.first.exception_class
      # Human-readable activity from the controller/action, for the form.
      assert_equal "using home", events.first.activity
      assert_equal 1, enqueued_jobs.count { |job| job[:job] == ReportErrorJob }
    end

    test "the report form offers recent errors and threads the chosen one into the issue" do
      user = create_user
      event = ErrorEvent.record!(user_id: user.id, fingerprint: "fp123", exception_class: "TypeError",
                                 message: "nil can't be coerced", activity: "viewing invoices",
                                 occurred_at: 5.minutes.ago)
      # Another user's event - must not appear in this user's form options.
      ErrorEvent.record!(user_id: create_user(email: "b@example.test").id, fingerprint: "fp999",
                         exception_class: "IOError", message: "other", occurred_at: 5.minutes.ago)

      sign_in user
      get "/bug_reports/new"
      # Users see what they were doing, never the exception itself.
      assert_select "select[name='bug_report[related_error_event_id]']" do
        assert_select "option", text: /Something went wrong while viewing invoices/
      end
      assert_no_match(/TypeError/, response.body)
      assert_no_match(/IOError/, response.body)

      stub_request(:post, "#{BugReportsClient::TestConfig::API_URL}/bug_reports")
        .to_return(status: 202, body: { id: 71 }.to_json)

      post "/bug_reports", params: {
        bug_report: {
          title: "Broken after error", report_type: "bug", severity: "high",
          related_error_event_id: event.id,
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" }
        }
      }

      assert_requested(:post, "#{BugReportsClient::TestConfig::API_URL}/bug_reports") do |request|
        description = JSON.parse(request.body)["bug_report"]["description"]
        description.include?("Related captured error") && description.include?("fp123")
      end
      # The issue gets the full technical detail the user never saw.
      assert_equal "TypeError: nil can't be coerced - while viewing invoices (fingerprint `fp123`, at #{event.occurred_at.iso8601})",
                   BugReport.last.response("related_error")
    end

    test "another user's error event cannot be linked" do
      user = create_user
      foreign = ErrorEvent.record!(user_id: create_user(email: "b@example.test").id, fingerprint: "fp999",
                                   exception_class: "IOError", message: "other", occurred_at: 5.minutes.ago)
      stub_request(:post, "#{BugReportsClient::TestConfig::API_URL}/bug_reports")
        .to_return(status: 202, body: { id: 72 }.to_json)

      sign_in user
      post "/bug_reports", params: {
        bug_report: {
          title: "Sneaky link", report_type: "bug", severity: "low",
          related_error_event_id: foreign.id,
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" }
        }
      }

      assert_nil BugReport.last.response("related_error")
    end

    test "the reporter never raises even if reporting itself fails" do
      reporter = ErrorReporter.new
      # An error whose own message raises - reporting it blows up internally,
      # which the reporter must swallow (never mask the original failure).
      hostile = ArgumentError.new("x")
      hostile.set_backtrace([ "#{Rails.root}/app/models/thing.rb:1:in `x'" ])
      def hostile.message = raise("kaboom")

      assert_nil reporter.report(hostile, handled: false)
    end
  end
end
