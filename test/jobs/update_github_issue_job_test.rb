require "test_helper"

class UpdateGithubIssueJobTest < ActiveJob::TestCase
  setup do
    @bug_report = bug_reports(:closed_report)
  end

  test "updates the github issue with current bug report data" do
    called_with = {}

    fake_client = Object.new
    fake_client.define_singleton_method(:update_issue) do |repo, issue_number, title, body, **opts|
      called_with = { repo: repo, issue_number: issue_number, title: title, body: body, opts: opts }
    end

    job = UpdateGithubIssueJob.new
    job.define_singleton_method(:github_client) { fake_client }
    job.perform(@bug_report.id)

    assert_equal @bug_report.github_repo, called_with[:repo]
    assert_equal @bug_report.github_issue_number, called_with[:issue_number]
    assert_equal @bug_report.title, called_with[:title]
    assert_includes called_with[:body], @bug_report.description
  end
end
