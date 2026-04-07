# Receives GitHub webhook events for bug report issues.
# When a linked issue is closed on GitHub, the corresponding
# bug report is marked as completed and the originating app is notified.
module Api
  class WebhooksController < ApplicationController
    def create
      event = request.headers["X-GitHub-Event"]
      payload = JSON.parse(request.body.read)

      if event == "issues" && payload["action"] == "closed"
        bug_report = BugReport.find_by(
          github_repo: payload["repository"]["full_name"],
          github_issue_number: payload["issue"]["number"]
        )

        if bug_report
          bug_report.update!(status: "closed")
          NotifySourceAppJob.perform_later(bug_report.id)
        end
      end

      head :ok
    end
  end
end
