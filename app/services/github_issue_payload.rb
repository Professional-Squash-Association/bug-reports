# Builds the exact payload we send to GitHub for a bug report's issue -
# repo, title, body and labels. Used by the create/update jobs, the dry-run
# logger, and the bug_reports:preview rake task, so what you preview is
# byte-for-byte what would be sent.
class GithubIssuePayload
  def self.for(bug_report)
    new(bug_report).to_h
  end

  def initialize(bug_report)
    @bug_report = bug_report
  end

  def to_h
    {
      repo: @bug_report.github_repo,
      title: @bug_report.title,
      body: body,
      labels: labels,
      type: issue_type
    }
  end

  # GitHub validates the issue type against the organisation's configured
  # list and rejects unknown values with a 422, failing the whole issue.
  # Error captures therefore default to the "bug" type (the error-report
  # label carries the distinction); organisations that define a custom type
  # for them can opt in via GITHUB_ERROR_ISSUE_TYPE (e.g. "Error").
  def issue_type
    @bug_report.error? ? ENV.fetch("GITHUB_ERROR_ISSUE_TYPE", "bug") : @bug_report.report_type
  end

  def body
    # Automatic error reports have no human reporter to credit.
    return @bug_report.description if @bug_report.error?

    "#{@bug_report.description}\n\n## Reported by\n#{@bug_report.reporter_name} (#{@bug_report.reporter_email})"
  end

  # The issue "type" (set separately) already conveys bug vs feature, so these
  # labels only mark provenance, severity (bugs only), and external reporters.
  # Automatic error captures get their own label.
  def labels
    labels = [ provenance_label ]
    labels << "severity:#{@bug_report.severity}" if @bug_report.severity.present?
    labels << "external-user" if @bug_report.reporter_external?
    labels
  end

  def provenance_label
    return "error-report" if @bug_report.error?

    @bug_report.feature? ? "feature-request" : "bug-report"
  end
end
