require "test_helper"

module BugReportsClient
  class ApiClientTest < ActiveSupport::TestCase
    API_ENDPOINT = "#{BugReportsClient::TestConfig::API_URL}/bug_reports".freeze

    test "raises when no API key is configured" do
      BugReportsClient.config.api_key = nil

      assert_raises(ApiClient::AuthenticationError) { ApiClient.new }
    end

    test "create_bug_report posts the payload with auth and returns the remote id" do
      stub_request(:post, API_ENDPOINT)
        .with(headers: { "Authorization" => "Bearer test-api-key", "Content-Type" => "application/json" })
        .to_return(status: 202, body: { id: 99, status: "queued" }.to_json)

      result = ApiClient.new.create_bug_report(
        title: "Broken page", description: "## Details", severity: "high",
        report_type: "bug", reporter_email: "jane@example.test", reporter_name: "Jane"
      )

      assert result.success?
      assert_equal 99, result.data["id"]
      assert_requested(:post, API_ENDPOINT) do |request|
        body = JSON.parse(request.body)["bug_report"]
        body["title"] == "[Bug]: Broken page" &&
          body["source"] == "dummy" &&
          body["callback_url"] == "https://dummy.example.test/bug_reports/webhook"
      end
    end

    test "feature titles get the feature prefix" do
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 1 }.to_json)

      ApiClient.new.create_bug_report(
        title: "New idea", description: "x", report_type: "feature", reporter_email: "jane@example.test"
      )

      assert_requested(:post, API_ENDPOINT) do |request|
        JSON.parse(request.body)["bug_report"]["title"] == "[Feature]: New idea"
      end
    end

    test "validation errors return a failed result with the API's messages" do
      stub_request(:post, API_ENDPOINT)
        .to_return(status: 422, body: { errors: [ "Severity is not included in the list" ] }.to_json)

      result = ApiClient.new.create_bug_report(
        title: "Broken", description: "x", reporter_email: "jane@example.test"
      )

      assert_not result.success?
      assert_match(/Severity is not included/, result.message)
    end

    test "auth failures return a failed result" do
      stub_request(:post, API_ENDPOINT).to_return(status: 401, body: { error: "Unauthorised" }.to_json)

      result = ApiClient.new.create_bug_report(
        title: "Broken", description: "x", reporter_email: "jane@example.test"
      )

      assert_not result.success?
    end

    test "timeouts are retried then succeed" do
      stub_request(:post, API_ENDPOINT)
        .to_timeout.then
        .to_return(status: 202, body: { id: 7 }.to_json)

      result = ApiClient.new.create_bug_report(
        title: "Broken", description: "x", reporter_email: "jane@example.test"
      )

      assert result.success?
      assert_equal 7, result.data["id"]
    end

    test "update_bug_report patches the remote record" do
      stub_request(:patch, "#{API_ENDPOINT}/42").to_return(status: 200, body: { id: 42 }.to_json)

      result = ApiClient.new.update_bug_report(42, title: "Updated", description: "y", severity: "low")

      assert result.success?
      assert_requested(:patch, "#{API_ENDPOINT}/42") do |request|
        JSON.parse(request.body)["bug_report"]["title"] == "[Bug]: Updated"
      end
    end

    test "missing source fails with a generic user-facing message" do
      BugReportsClient.config.source = nil
      stub_request(:post, API_ENDPOINT)

      result = ApiClient.new.create_bug_report(
        title: "Broken", description: "x", reporter_email: "jane@example.test"
      )

      assert_not result.success?
      # Internal details (config errors, hosts, URLs) stay in the log - users
      # only ever see the generic failure message.
      assert_equal I18n.t("bug_reports_client.flashes.submit_failed"), result.message
    end
  end
end
