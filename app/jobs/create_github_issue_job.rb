# Creates a GitHub issue on the mapped repository for a bug report.
# On success, stores the issue number and URL back on the bug report record.
class CreateGithubIssueJob < ApplicationJob
  include GithubIssueJob

  def perform(bug_report_id)
    bug_report = find_bug_report(bug_report_id)

    gh_issue = github_client.create_issue(
      bug_report.github_repo,
      bug_report.title,
      build_issue_body(bug_report),
      labels: build_labels(bug_report),
      type: bug_report.report_type
    )

    bug_report.update!(
      github_issue_number: gh_issue.number,
      github_issue_url: gh_issue.html_url
    )
  end
end
