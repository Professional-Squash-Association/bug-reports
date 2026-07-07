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
    GithubApp.client
  end

  def build_issue_body(bug_report)
    "#{bug_report.description}\n\n## Reported by\n#{bug_report.reporter_name} (#{bug_report.reporter_email})"
  end

  # The issue "type" (set separately) already conveys bug vs feature, so these
  # labels only mark provenance, severity (bugs only), and external reporters.
  def build_labels(bug_report)
    labels = [ bug_report.feature? ? "feature-request" : "bug-report" ]
    labels << "severity:#{bug_report.severity}" if bug_report.severity.present?
    labels << "external-user" if bug_report.reporter_external?
    labels
  end
end
