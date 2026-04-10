# Updates a GitHub issue to reflect changes made to a bug report.
# Syncs the title, body, and labels with the linked GitHub issue.
class UpdateGithubIssueJob < ApplicationJob
  include GithubIssueJob

  def perform(bug_report_id)
    bug_report = find_bug_report(bug_report_id)

    github_client.update_issue(
      bug_report.github_repo,
      bug_report.github_issue_number,
      bug_report.title,
      build_issue_body(bug_report),
      labels: build_labels(bug_report),
      type: bug_report.report_type
    )
  end
end
