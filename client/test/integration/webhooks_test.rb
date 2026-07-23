require "test_helper"

module BugReportsClient
  class WebhooksTest < ActionDispatch::IntegrationTest
    setup do
      @user = create_user
      @report = create_bug_report(user: @user, remote_bug_report_id: 55)
      @payload = { bug_report_id: 55, title: "Something is broken", source: "dummy", status: "closed" }.to_json
    end

    test "a correctly signed callback closes the local report" do
      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => signature(@payload) }

      assert_response :ok
      assert_equal "closed", @report.reload.status
    end

    test "an invalid signature is rejected" do
      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => "sha256=deadbeef" }

      assert_response :unauthorized
      assert_equal "open", @report.reload.status
    end

    test "a missing signature is rejected" do
      post "/bug_reports/webhook", params: @payload, headers: { "Content-Type" => "application/json" }

      assert_response :unauthorized
    end

    test "a missing webhook secret rejects rather than accepting anything" do
      BugReportsClient.config.webhook_secret = nil

      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => signature(@payload) }

      assert_response :unauthorized
    end

    test "a report that no longer passes validation can still be closed" do
      # Simulates a legacy record predating a schema change: bypass
      # validations to store a report with no responses at all.
      @report.update_columns(responses: {})

      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => signature(@payload) }

      assert_response :ok
      assert_equal "closed", @report.reload.status
    end

    test "an unknown remote id is acknowledged without error" do
      payload = { bug_report_id: 999_999, title: "Unknown" }.to_json

      post "/bug_reports/webhook", params: payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => signature(payload) }

      assert_response :ok
    end

    test "a fresh timestamped signature is accepted" do
      timestamp = Time.current.to_i.to_s

      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json",
                   "X-Timestamp" => timestamp,
                   "X-Signature-Timestamped" => timestamped_signature(timestamp, @payload) }

      assert_response :ok
      assert_equal "closed", @report.reload.status
    end

    test "a stale timestamp is rejected even with a valid signature" do
      timestamp = 10.minutes.ago.to_i.to_s

      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json",
                   "X-Timestamp" => timestamp,
                   "X-Signature-Timestamped" => timestamped_signature(timestamp, @payload) }

      assert_response :unauthorized
      assert_equal "open", @report.reload.status
    end

    test "a timestamped request cannot fall back to the legacy body signature" do
      # Replaying a captured legacy signature with a fresh timestamp must fail.
      post "/bug_reports/webhook", params: @payload,
        headers: { "Content-Type" => "application/json",
                   "X-Timestamp" => Time.current.to_i.to_s,
                   "X-Signature" => signature(@payload) }

      assert_response :unauthorized
    end

    test "oversized bodies are rejected before verification" do
      post "/bug_reports/webhook", params: "x" * 2.megabytes,
        headers: { "Content-Type" => "application/json" }

      assert_response :content_too_large
    end

    test "malformed JSON returns unprocessable" do
      payload = "not-json"

      post "/bug_reports/webhook", params: payload,
        headers: { "Content-Type" => "application/json", "X-Signature" => signature(payload) }

      assert_response :unprocessable_entity
    end

    private

    def signature(body)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'test-webhook-secret', body)}"
    end

    def timestamped_signature(timestamp, body)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'test-webhook-secret', "#{timestamp}.#{body}")}"
    end
  end
end
