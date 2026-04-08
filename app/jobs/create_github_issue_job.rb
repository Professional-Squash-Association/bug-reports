# Creates a GitHub issue on the mapped repository for a bug report.
# Retries up to 5 times with polynomial backoff if the GitHub API fails.
# On success, stores the issue number and URL back on the bug report record.
class CreateGithubIssueJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(bug_report_id)
    bug_report = BugReport.find(bug_report_id)
    client = Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))

    gh_issue = client.create_issue(
      bug_report.github_repo,
      bug_report.title,
      build_issue_body(bug_report),
      labels: build_labels(bug_report)
    )

    bug_report.update!(
      github_issue_number: gh_issue.number,
      github_issue_url: gh_issue.html_url
    )
  end

  private

  def build_issue_body(bug_report)
    "#{bug_report.description}\n\n## Reported by\n#{bug_report.reporter_name} (#{bug_report.reporter_email})"
  end

  def build_labels(bug_report)
    [ "bug-report", "bug", "severity:#{bug_report.severity}", "source:#{bug_report.source}" ]
  end
end
