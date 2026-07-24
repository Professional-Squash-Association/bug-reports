# Receives GitHub webhook events for bug report issues.
# When a linked issue is closed on GitHub, the corresponding
# bug report is marked as completed and the originating app is notified.
module Api
  class WebhooksController < ApplicationController
    before_action :verify_github_signature

    def create
      event = request.headers["X-GitHub-Event"]
      payload = JSON.parse(request.body.read)

      # Closure and deletion are both terminal for a report. Deletion also
      # clears the issue reference so nothing points at (or tries to sync) a
      # dead issue, and a recurring error files a fresh issue rather than
      # counting occurrences against one nobody can see.
      if event == "issues" && %w[closed deleted].include?(payload["action"])
        bug_report = BugReport.find_by(
          github_repo: payload["repository"]["full_name"],
          github_issue_number: payload["issue"]["number"]
        )

        if bug_report
          bug_report.update!(status: "closed")
          bug_report.update!(github_issue_number: nil, github_issue_url: nil) if payload["action"] == "deleted"
          # Error reports have no reporter to notify (no callback_url).
          NotifySourceAppJob.perform_later(bug_report.id) if bug_report.callback_url.present?
        end
      end

      head :ok
    end

    private

    def verify_github_signature
      signature = request.headers["X-Hub-Signature-256"]
      unless signature.present?
        head :unauthorized
        return
      end

      body = request.body.read
      request.body.rewind
      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("GITHUB_WEBHOOK_SECRET"), body)}"

      unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
        head :unauthorized
      end
    end
  end
end
