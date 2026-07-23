# Updates a GitHub issue to reflect changes made to a bug report.
# Syncs the title, body, and labels with the linked GitHub issue.
# In dry-run mode (development, or GITHUB_DRY_RUN=true) the payload is logged
# instead of sent, so local testing never touches real issues.
class UpdateGithubIssueJob < ApplicationJob
  include GithubIssueJob

  def perform(bug_report_id)
    bug_report = find_bug_report(bug_report_id)

    if GithubDryRun.active?
      GithubDryRun.log("update", bug_report)
      return
    end

    payload = GithubIssuePayload.for(bug_report)
    github_client.update_issue(
      payload[:repo],
      bug_report.github_issue_number,
      payload[:title],
      payload[:body],
      labels: payload[:labels],
      type: payload[:type]
    )
  end
end
