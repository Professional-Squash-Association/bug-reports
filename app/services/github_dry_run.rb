# Dry-run mode for GitHub issue creation/updates. Active in development (so
# local testing never files real issues) or when GITHUB_DRY_RUN=true is set
# in any environment. Instead of calling GitHub, the full issue payload is
# written to the log - see also `bin/rails bug_reports:preview` to inspect
# payloads for stored reports at any time.
class GithubDryRun
  def self.active?
    Rails.env.development? || ENV["GITHUB_DRY_RUN"] == "true"
  end

  # Logs (and returns) a readable rendering of the payload that would have
  # been sent for the given action ("create" or "update").
  def self.log(action, bug_report)
    message = render(action, bug_report)
    Rails.logger.info(message)
    message
  end

  def self.render(action, bug_report)
    payload = GithubIssuePayload.for(bug_report)
    issue_ref = bug_report.github_issue_number ? " ##{bug_report.github_issue_number}" : ""

    <<~MESSAGE
      ========== GITHUB DRY RUN: #{action} issue#{issue_ref} (bug report #{bug_report.id}) ==========
      Repo:   #{payload[:repo]}
      Title:  #{payload[:title]}
      Type:   #{payload[:type]}
      Labels: #{payload[:labels].join(', ')}
      ---------- issue body ----------
      #{payload[:body]}
      ================================================================
    MESSAGE
  end
end
