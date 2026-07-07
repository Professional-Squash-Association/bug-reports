require "test_helper"

class CreateGithubIssueJobTest < ActiveJob::TestCase
  setup do
    @bug_report = bug_reports(:pending_report)
  end

  test "creates a github issue and stores the number and url" do
    fake_issue = Data.define(:number, :html_url).new(
      number: 99,
      html_url: "https://github.com/example/repo/issues/99"
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:create_issue) { |_repo, _title, _body, **_opts| fake_issue }

    job = CreateGithubIssueJob.new
    job.define_singleton_method(:github_client) { fake_client }
    job.perform(@bug_report.id)

    @bug_report.reload
    assert_equal 99, @bug_report.github_issue_number
    assert_equal "https://github.com/example/repo/issues/99", @bug_report.github_issue_url
  end

  test "issue body includes description and reporter info" do
    captured_body = nil

    fake_client = Object.new
    fake_client.define_singleton_method(:create_issue) do |_repo, _title, body, **_opts|
      captured_body = body
      Data.define(:number, :html_url).new(number: 1, html_url: "https://github.com/example/repo/issues/1")
    end

    job = CreateGithubIssueJob.new
    job.define_singleton_method(:github_client) { fake_client }
    job.perform(@bug_report.id)

    assert_includes captured_body, @bug_report.description
    assert_includes captured_body, @bug_report.reporter_name
    assert_includes captured_body, @bug_report.reporter_email
  end

  test "a bug report carries the bug-report provenance label and its severity" do
    opts = capture_issue_opts(bug_reports(:pending_report))

    assert_equal "bug", opts[:type]
    assert_equal [ "bug-report", "severity:medium" ], opts[:labels]
  end

  test "a feature report from an external reporter is labelled accordingly" do
    opts = capture_issue_opts(bug_reports(:feature_report))

    assert_equal "feature", opts[:type]
    assert_equal [ "feature-request", "external-user" ], opts[:labels]
  end

  private

  def capture_issue_opts(bug_report)
    captured = nil

    fake_client = Object.new
    fake_client.define_singleton_method(:create_issue) do |_repo, _title, _body, **opts|
      captured = opts
      Data.define(:number, :html_url).new(number: 1, html_url: "https://github.com/example/repo/issues/1")
    end

    job = CreateGithubIssueJob.new
    job.define_singleton_method(:github_client) { fake_client }
    job.perform(bug_report.id)

    captured
  end
end
