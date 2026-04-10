# Updates a GitHub issue to reflect changes made to a bug report.
# Syncs the title, body, and labels with the linked GitHub issue.
# Retries up to 5 times with polynomial backoff if the GitHub API fails.
class UpdateGithubIssueJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(bug_report_id)
    bug_report = BugReport.find(bug_report_id)
    client = Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))

    client.update_issue(
      bug_report.github_repo,
      bug_report.github_issue_number,
      bug_report.title,
      build_issue_body(bug_report),
      labels: build_labels(bug_report),
      type: bug_report.report_type
    )
  end

  private

  def build_issue_body(bug_report)
    "#{bug_report.description}\n\n## Reported by\n#{bug_report.reporter_name} (#{bug_report.reporter_email})"
  end

  def build_labels(bug_report)
    [ "bug-report", "severity:#{bug_report.severity}" ]
  end
end
