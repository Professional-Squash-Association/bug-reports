require "test_helper"

# Covers the automatic error-report endpoint: creation, fingerprint
# deduplication, regression (closed -> new issue), auth and ownership.
class ErrorReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = api_keys(:secure)
    @headers = { "Authorization" => "Bearer #{@api_key.token}", "Content-Type" => "application/json" }
    @payload = {
      error_report: {
        title: "[Error]: NoMethodError in app/models/player.rb:12",
        description: "## NoMethodError\nundefined method `foo'",
        source: "secure",
        fingerprint: "abc123def456",
        occurred_at: Time.current.iso8601
      }
    }
  end

  test "creates an error report and queues issue creation" do
    assert_enqueued_with(job: CreateGithubIssueJob) do
      post api_error_reports_url, params: @payload.to_json, headers: @headers
    end

    assert_response :accepted
    report = BugReport.last
    assert_equal "error", report.report_type
    assert_equal "high", report.severity
    assert_equal "abc123def456", report.fingerprint
    assert_equal 1, report.occurrence_count
    assert_equal ApiKey.repo_for("secure"), report.github_repo
    assert_nil report.callback_url
  end

  test "a repeat of an open error bumps the occurrence count instead of duplicating" do
    post api_error_reports_url, params: @payload.to_json, headers: @headers
    first_id = JSON.parse(response.body)["id"]

    assert_no_enqueued_jobs(only: CreateGithubIssueJob) do
      post api_error_reports_url, params: @payload.to_json, headers: @headers
    end

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal first_id, body["id"]
    assert_equal "duplicate", body["status"]
    assert_equal 2, BugReport.find(first_id).occurrence_count
    assert_equal 1, BugReport.where(fingerprint: "abc123def456").count
  end

  test "a recurrence after the issue was closed files a fresh report" do
    post api_error_reports_url, params: @payload.to_json, headers: @headers
    BugReport.last.update!(status: "closed")

    assert_enqueued_with(job: CreateGithubIssueJob) do
      post api_error_reports_url, params: @payload.to_json, headers: @headers
    end

    assert_response :accepted
    assert_equal 2, BugReport.where(fingerprint: "abc123def456").count
  end

  test "error issues are filed with the bug issue type" do
    # GitHub rejects unknown org-level issue types (422), and "error" is not
    # one - the error-report label carries the distinction instead.
    post api_error_reports_url, params: @payload.to_json, headers: @headers

    payload = GithubIssuePayload.for(BugReport.last)
    assert_equal "bug", payload[:type]
    assert_includes payload[:labels], "error-report"
  end

  test "a custom error issue type can be configured" do
    post api_error_reports_url, params: @payload.to_json, headers: @headers

    ENV["GITHUB_ERROR_ISSUE_TYPE"] = "Error"
    assert_equal "Error", GithubIssuePayload.for(BugReport.last)[:type]
  ensure
    ENV.delete("GITHUB_ERROR_ISSUE_TYPE")
  end

  test "requires authentication" do
    post api_error_reports_url, params: @payload.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "rejects reports for a source the key does not own" do
    other = @payload.deep_dup
    other[:error_report][:source] = "otherapp"

    post api_error_reports_url, params: other.to_json, headers: @headers
    assert_response :forbidden
  end

  test "rejects reports without a fingerprint" do
    bad = @payload.deep_dup
    bad[:error_report].delete(:fingerprint)

    post api_error_reports_url, params: bad.to_json, headers: @headers
    assert_response :unprocessable_entity
  end
end
