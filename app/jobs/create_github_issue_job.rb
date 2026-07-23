# Creates a GitHub issue on the mapped repository for a bug report.
# On success, stores the issue number and URL back on the bug report record.
# In dry-run mode (development, or GITHUB_DRY_RUN=true) the payload is logged
# instead of sent, so local testing never files real issues.
class CreateGithubIssueJob < ApplicationJob
  include GithubIssueJob

  def perform(bug_report_id)
    bug_report = find_bug_report(bug_report_id)

    if GithubDryRun.active?
      GithubDryRun.log("create", bug_report)
      return
    end

    payload = GithubIssuePayload.for(bug_report)
    gh_issue = github_client.create_issue(
      payload[:repo],
      payload[:title],
      payload[:body],
      labels: payload[:labels],
      type: payload[:type]
    )

    bug_report.update!(
      github_issue_number: gh_issue.number,
      github_issue_url: gh_issue.html_url
    )
  end
end
