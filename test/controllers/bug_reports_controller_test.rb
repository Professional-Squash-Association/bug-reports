require "test_helper"

class Api::BugReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = api_keys(:secure)
    @headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key.token}"
    }
  end

  def valid_params
    {
      bug_report: {
        title: "New bug",
        description: "Something broke",
        severity: "high",
        source: "secure",
        reporter_email: "test@example.com",
        reporter_name: "Test User",
        callback_url: "https://secure.example.com/api/bug_report_updates"
      }
    }
  end

  # Authentication

  test "returns 401 without auth header" do
    post api_bug_reports_url, params: valid_params.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post api_bug_reports_url, params: valid_params.to_json,
      headers: @headers.merge("Authorization" => "Bearer invalid")
    assert_response :unauthorized
  end

  # Create

  test "create returns 202 and enqueues job" do
    assert_enqueued_with(job: CreateGithubIssueJob) do
      post api_bug_reports_url, params: valid_params.to_json, headers: @headers
    end

    assert_response :accepted
    json = JSON.parse(response.body)
    assert json["id"].present?
    assert_equal "queued", json["status"]
  end

  test "create sets github_repo from source mapping" do
    post api_bug_reports_url, params: valid_params.to_json, headers: @headers
    report = BugReport.last
    assert_equal RepoMapping.repo_for("secure"), report.github_repo
  end

  test "create returns 422 with invalid params" do
    invalid = { bug_report: { title: "", source: "secure" } }
    post api_bug_reports_url, params: invalid.to_json, headers: @headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any?
  end

  test "create returns 422 with unknown source" do
    params = valid_params.deep_merge(bug_report: { source: "unknown_app" })
    post api_bug_reports_url, params: params.to_json, headers: @headers

    assert_response :forbidden
  end

  # Show

  test "show returns bug report" do
    report = bug_reports(:pending_report)
    get api_bug_report_url(report), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal report.title, json["title"]
  end

  # Update

  test "update returns 200 and updates the record" do
    report = bug_reports(:pending_report)
    params = { bug_report: { title: "Updated title", severity: "critical" } }

    patch api_bug_report_url(report), params: params.to_json, headers: @headers

    assert_response :success
    report.reload
    assert_equal "Updated title", report.title
    assert_equal "critical", report.severity
  end

  test "update enqueues UpdateGithubIssueJob when github issue exists" do
    report = bug_reports(:closed_report)
    params = { bug_report: { title: "Updated title" } }

    assert_enqueued_with(job: UpdateGithubIssueJob) do
      patch api_bug_report_url(report), params: params.to_json, headers: @headers
    end
  end

  test "update does not enqueue job when no github issue linked" do
    report = bug_reports(:pending_report)
    params = { bug_report: { title: "Updated title" } }

    assert_no_enqueued_jobs(only: UpdateGithubIssueJob) do
      patch api_bug_report_url(report), params: params.to_json, headers: @headers
    end
  end

  test "update returns 422 with invalid params" do
    report = bug_reports(:pending_report)
    params = { bug_report: { severity: "extreme" } }

    patch api_bug_report_url(report), params: params.to_json, headers: @headers
    assert_response :unprocessable_entity
  end

  # Index

  test "index returns bug reports" do
    get api_bug_reports_url, headers: @headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
end
