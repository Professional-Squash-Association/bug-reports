# Creates a GitHub issue on the mapped repository for a bug report.
# Retries up to 5 times with polynomial backoff if the GitHub API fails.
# On success, stores the issue number and URL back on the bug report record.
class CreateGithubIssueJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(bug_report_id)
    bug_report = BugReport.find(bug_report_id)
    client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])

    body = build_issue_body(bug_report)

    gh_issue = client.create_issue(
      bug_report.github_repo,
      bug_report.title,
      body,
      labels: build_labels(bug_report)
    )

    bug_report.update!(
      github_issue_number: gh_issue.number,
      github_issue_url: gh_issue.html_url
    )
  end

  private

  def build_issue_body(bug_report)
    parts = []
    parts << bug_report.description if bug_report.description.present?
    parts << "## How can we see this for ourselves?\n#{bug_report.steps_to_reproduce}" if bug_report.steps_to_reproduce.present?
    if bug_report.image_url.present?
      screenshots = bug_report.image_url.split(",").map.with_index(1) do |url, i|
        "![screenshot-#{i}](#{url.strip})"
      end
      parts << "## Screenshots\n#{screenshots.join("\n")}"
    end
    parts << "## Reported by\n#{bug_report.reporter_name} (#{bug_report.reporter_email})"
    parts.join("\n\n")
  end

  def build_labels(bug_report)
    labels = [ "bug-report" ]
    labels = [ "bug" ]
    labels << "severity:#{bug_report.severity}" if bug_report.severity.present?
    labels << "source:#{bug_report.source}" if bug_report.source.present?
    labels
  end
end
