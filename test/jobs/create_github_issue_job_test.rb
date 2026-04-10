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
end
