# Shared behavior for jobs that interact with GitHub issues.
# Provides a configured Octokit client and common body/label builders.
module GithubIssueJob
  extend ActiveSupport::Concern

  included do
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
  end

  private

  def find_bug_report(id)
    BugReport.find(id)
  end

  def github_client
    Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
  end

  def build_issue_body(bug_report)
    "#{bug_report.description}\n\n## Reported by\n#{bug_report.reporter_name} (#{bug_report.reporter_email})"
  end

  def build_labels(bug_report)
    [ "bug", "bug-report", "severity:#{bug_report.severity}" ]
  end
end
