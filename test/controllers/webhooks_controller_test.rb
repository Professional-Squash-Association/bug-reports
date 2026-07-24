require "test_helper"

# Covers the GitHub webhook receiver: issue closure and deletion are both
# terminal for a report, deletion clears the dead issue reference, and
# signatures are verified.
class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["GITHUB_WEBHOOK_SECRET"] ||= "test_github_secret"
    @report = bug_reports(:pending_report)
    @report.update!(github_issue_number: 77)
  end

  test "issue closed marks the report closed and notifies the source app" do
    assert_enqueued_with(job: NotifySourceAppJob) do
      post_webhook(action: "closed", issue_number: 77)
    end

    assert_response :ok
    assert_equal "closed", @report.reload.status
    assert_equal 77, @report.github_issue_number
  end

  test "issue deleted closes the report and clears the dead issue reference" do
    assert_enqueued_with(job: NotifySourceAppJob) do
      post_webhook(action: "deleted", issue_number: 77)
    end

    assert_response :ok
    @report.reload
    assert_equal "closed", @report.status
    assert_nil @report.github_issue_number
    assert_nil @report.github_issue_url
  end

  test "closing an error report does not enqueue a callback" do
    error_report = BugReport.create!(
      title: "[Error] Boom", description: "x", source: "secure", report_type: "error",
      severity: "high", fingerprint: "fp_del", github_repo: ApiKey.repo_for("secure"),
      github_issue_number: 88
    )

    assert_no_enqueued_jobs(only: NotifySourceAppJob) do
      post_webhook(action: "closed", issue_number: 88)
    end

    assert_equal "closed", error_report.reload.status
  end

  test "an error recurring after its issue was deleted files a fresh issue" do
    BugReport.create!(
      title: "[Error] Boom", description: "x", source: "secure", report_type: "error",
      severity: "high", fingerprint: "fp_del", github_repo: ApiKey.repo_for("secure"),
      github_issue_number: 88
    )
    post_webhook(action: "deleted", issue_number: 88)

    assert_enqueued_with(job: CreateGithubIssueJob) do
      post api_error_reports_url,
        params: { error_report: { title: "[Error] Boom", description: "x", source: "secure",
                                  fingerprint: "fp_del", occurred_at: Time.current.iso8601 } }.to_json,
        headers: { "Authorization" => "Bearer #{api_keys(:secure).token}", "Content-Type" => "application/json" }
    end

    assert_response :accepted
    assert_equal 2, BugReport.where(fingerprint: "fp_del").count
  end

  test "unrelated issue events are acknowledged without changes" do
    post_webhook(action: "opened", issue_number: 77)

    assert_response :ok
    assert_equal "pending", @report.reload.status
  end

  test "invalid signatures are rejected" do
    payload = webhook_payload(action: "closed", issue_number: 77)

    post api_webhooks_url, params: payload,
      headers: { "Content-Type" => "application/json",
                 "X-GitHub-Event" => "issues",
                 "X-Hub-Signature-256" => "sha256=deadbeef" }

    assert_response :unauthorized
    assert_equal "pending", @report.reload.status
  end

  private

  def webhook_payload(action:, issue_number:)
    {
      action: action,
      repository: { full_name: "example-org/secure" },
      issue: { number: issue_number }
    }.to_json
  end

  def post_webhook(action:, issue_number:)
    payload = webhook_payload(action: action, issue_number: issue_number)
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', ENV.fetch('GITHUB_WEBHOOK_SECRET'), payload)}"

    post api_webhooks_url, params: payload,
      headers: { "Content-Type" => "application/json",
                 "X-GitHub-Event" => "issues",
                 "X-Hub-Signature-256" => signature }
  end
end
