# Handles bug report submissions from PSA applications.
# Persists the report, enqueues a job to create the GitHub issue,
# and returns a confirmation to the calling app.
module Api
  class BugReportsController < ApplicationController
    before_action :authenticate_api_key
    before_action :verify_source_ownership, only: %i[create update]

    def create
      bug_report = BugReport.new(bug_report_params)
      bug_report.github_repo = bug_report.resolved_repo

      if bug_report.save
        CreateGithubIssueJob.perform_later(bug_report.id)
        render json: { id: bug_report.id, status: "queued" }, status: :accepted
      else
        render json: { errors: bug_report.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
      bug_report = BugReport.find(params[:id])
      render json: bug_report
    end

    def index
      bug_reports = BugReport.order(created_at: :desc)
      render json: bug_reports
    end

    # PATCH /api/bug_reports/:id
    def update
      bug_report = BugReport.find(params[:id])

      if bug_report.update(bug_report_params)
        UpdateGithubIssueJob.perform_later(bug_report.id) if bug_report.github_issue_number.present?
        render json: bug_report
      else
        render json: { errors: bug_report.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def verify_source_ownership
      source = if action_name == "create"
        params.dig(:bug_report, :source)
      else
        BugReport.find(params[:id]).source
      end

      head :forbidden unless source == current_api_key.name
    end

    def bug_report_params
      params.require(:bug_report).permit(
        :title, :description, :severity, :report_type, :source,
        :reporter_email, :reporter_name, :callback_url
      )
    end
  end
end
