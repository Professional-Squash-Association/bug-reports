# Receives automatic error reports (unhandled 500s) from consuming apps.
# Deduplicates by source + fingerprint: an open report for the same error
# bumps its occurrence count; otherwise a new report (and GitHub issue) is
# created - including when a previously-closed error recurs (a regression
# deserves a fresh issue).
module Api
  class ErrorReportsController < ApplicationController
    before_action :authenticate_api_key
    before_action :verify_source_ownership

    def create
      occurred_at = parsed_occurred_at

      existing = BugReport.open_error_for(current_api_key.name, error_report_params[:fingerprint]).first
      if existing
        existing.record_occurrence!(occurred_at)
        render json: { id: existing.id, status: "duplicate", occurrence_count: existing.occurrence_count }, status: :ok
        return
      end

      error_report = BugReport.new(error_report_params.except(:occurred_at))
      error_report.report_type = "error"
      error_report.severity ||= "high"
      error_report.last_occurred_at = occurred_at
      error_report.github_repo = error_report.resolved_repo

      if error_report.save
        CreateGithubIssueJob.perform_later(error_report.id)
        render json: { id: error_report.id, status: "queued" }, status: :accepted
      else
        render json: { errors: error_report.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def verify_source_ownership
      head :forbidden unless params.dig(:error_report, :source) == current_api_key.name
    end

    def error_report_params
      params.require(:error_report).permit(:title, :description, :severity, :source, :fingerprint, :occurred_at)
    end

    def parsed_occurred_at
      Time.zone.parse(error_report_params[:occurred_at].to_s) || Time.current
    rescue ArgumentError
      Time.current
    end
  end
end
