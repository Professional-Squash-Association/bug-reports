module BugReportsClient
  # Handles report submission, editing, listing and dismissal of resolved
  # alerts. Reports are saved locally (screenshots via Active Storage), then
  # submitted to the central bug-reports API which files a GitHub issue; the
  # remote ID is stored so closure webhooks can find the local record.
  class BugReportsController < ApplicationController
    PER_PAGE = 20

    before_action :set_bug_report, only: %i[edit update]
    before_action :authorize_bug_report_access!, only: %i[edit update]
    before_action :require_admin!, only: %i[all]

    # GET /  (engine root) - the current user's reports
    def index
      reports = BugReport.where(user: bug_reports_current_user)
      @bug_reports = paginate(filtered(reports).order(created_at: :desc))

      @counts = status_counts(reports)
      @type_counts = type_counts(reports)
    end

    # GET /all (admins via config.admin_check) - every report from this app
    def all
      @bug_reports = paginate(filtered(BugReport.includes(:user)).order(created_at: :desc))

      @counts = status_counts(BugReport)
      @type_counts = type_counts(BugReport)
    end

    # GET /new
    def new
      @bug_report = BugReport.new
      @recent_error_events = recent_error_events
    end

    # GET /:id/edit - form for open (editable) and closed (read-only) reports
    def edit
    end

    # POST /
    # Saves the report and screenshots locally, submits to the API, then
    # stores the returned remote ID. A failed API call rolls the local record
    # back so users can retry without creating orphans.
    def create
      @bug_report = BugReport.new(bug_report_params)
      @bug_report.user = bug_reports_current_user
      apply_default_severity(@bug_report)
      link_related_error(@bug_report)
      @recent_error_events = recent_error_events

      # Screenshot files are validated server-side (type sniffed, size and
      # count checked) BEFORE anything is attached or saved.
      unless validate_screenshots(@bug_report, submitted_screenshots)
        render :new, status: :unprocessable_entity
        return
      end
      attach_screenshots(@bug_report)

      unless @bug_report.save
        render :new, status: :unprocessable_entity
        return
      end

      result = ApiClient.new.create_bug_report(
        title: @bug_report.title,
        description: DescriptionBuilder.new(@bug_report).build,
        severity: @bug_report.severity,
        report_type: @bug_report.report_type,
        reporter_email: BugReportsClient.config.reporter_email_for(bug_reports_current_user),
        reporter_name: BugReportsClient.config.reporter_name_for(bug_reports_current_user),
        reporter_external: BugReportsClient.config.external_reporter?(bug_reports_current_user)
      )

      if result.success?
        @bug_report.update!(remote_bug_report_id: result.data["id"])
        redirect_to bug_reports_path, notice: t("bug_reports_client.flashes.created", type_noun: @bug_report.type_noun.capitalize)
      else
        # Surface the failure in the form's error box (which scrolls itself
        # into view) rather than a top-of-page flash the user may never see.
        @bug_report.destroy
        @bug_report = BugReport.new
        @bug_report.errors.add(:base, result.message)
        render :new, status: :unprocessable_entity
      end
    rescue ApiClient::ApiError => e
      @bug_report.destroy if @bug_report&.persisted?
      @bug_report = BugReport.new
      @bug_report.errors.add(:base, t("bug_reports_client.flashes.submit_failed"))
      Rails.logger.error "BugReportsClient: submission failed: #{e.message}"
      render :new, status: :unprocessable_entity
    end

    # PATCH /:id
    # Two cases: dismissing a resolved alert (no bug_report params), or
    # editing an open report (re-syncs the remote issue).
    def update
      return dismiss_bug_report if params[:bug_report].blank?

      unless @bug_report.open?
        redirect_to edit_bug_report_path(@bug_report), alert: t("bug_reports_client.flashes.only_open_editable", type_noun: @bug_report.type_noun)
        return
      end

      # The report type is locked once submitted - the remote issue and its
      # labels are already filed as that type.
      @bug_report.assign_attributes(bug_report_params.except(:report_type))
      apply_default_severity(@bug_report)

      # Attaching to a persisted record writes immediately (bypassing model
      # validations), so the new files must be validated before anything is
      # saved or purged.
      new_screenshots = submitted_screenshots
      unless validate_screenshots(@bug_report, new_screenshots)
        render :edit, status: :unprocessable_entity
        return
      end

      if @bug_report.save
        # New uploads replace the existing set; editing without choosing any
        # files leaves the current screenshots alone.
        if new_screenshots.any?
          @bug_report.screenshots.purge
          @bug_report.screenshots.attach(new_screenshots)
        end

        if @bug_report.remote_bug_report_id.present?
          ApiClient.new.update_bug_report(
            @bug_report.remote_bug_report_id,
            title: @bug_report.title,
            description: DescriptionBuilder.new(@bug_report).build,
            severity: @bug_report.severity,
            report_type: @bug_report.report_type
          )
        end

        redirect_to edit_bug_report_path(@bug_report), notice: t("bug_reports_client.flashes.updated", type_noun: @bug_report.type_noun.capitalize)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_bug_report
      @bug_report = BugReport.find(params[:id])
    end

    def authorize_bug_report_access!
      unless @bug_report.user_id == bug_reports_current_user.id || bug_reports_admin?
        head :forbidden
      end
    end

    def require_admin!
      unless bug_reports_admin?
        redirect_to bug_reports_path, alert: t("bug_reports_client.flashes.not_permitted")
      end
    end

    # Only the SELECTED type's schema field keys are permitted into
    # responses, so a tampered form can't write arbitrary data or smuggle the
    # other type's answers in. Screenshots are permitted (silencing
    # unpermitted-parameter noise) but excluded from mass assignment -
    # attachment is handled explicitly below.
    def bug_report_params
      report_type = @bug_report&.persisted? ? @bug_report.report_type : params.dig(:bug_report, :report_type)

      params.require(:bug_report).permit(
        :title, :severity, :report_type, :related_error_event_id,
        screenshots: [],
        responses: BugReportsClient.form_schema.field_keys_for(report_type)
      ).except(:screenshots, :related_error_event_id)
    end

    # Captured 500s this user hit recently, offered on the form as "did your
    # problem relate to this error?".
    def recent_error_events
      ErrorEvent.where(user: bug_reports_current_user).since(24.hours.ago).recent_first.limit(5)
    end

    # If the reporter linked one of their captured errors, thread its details
    # into the report (rendered into the GitHub issue by DescriptionBuilder,
    # where the fingerprint cross-references the auto-filed error issue).
    # Scoped to the current user so ids can't be guessed across accounts.
    def link_related_error(report)
      event_id = params.dig(:bug_report, :related_error_event_id)
      return if event_id.blank?

      event = ErrorEvent.where(user: bug_reports_current_user).find_by(id: event_id)
      return unless event

      # Full technical detail for the issue - the user only ever saw the
      # human description.
      details = [ event.summary ]
      details << "while #{event.activity}" if event.activity.present?
      report.responses = {
        "related_error" => "#{details.join(' - ')} (fingerprint `#{event.fingerprint}`, at #{event.occurred_at.iso8601})"
      }
    end

    # The submitted screenshot files, minus the blank entry a multiple file
    # input always includes. An edit without new uploads therefore submits
    # no files and existing screenshots are left untouched.
    def submitted_screenshots
      return [] unless BugReportsClient.config.screenshots_enabled

      Array(params.dig(:bug_report, :screenshots)).reject(&:blank?)
    end

    # Consumer-facing hosts hide the severity picker; the API still requires
    # a severity for bugs, so fill in the configured default.
    def apply_default_severity(report)
      return if BugReportsClient.config.ask_severity
      report.severity = BugReportsClient.config.default_severity if report.bug?
    end

    def attach_screenshots(report)
      files = submitted_screenshots
      report.screenshots.attach(files) if files.any?
    end

    # Server-side screenshot validation, run before any attach: count within
    # the limit, size within bounds, and the content type sniffed from the
    # file bytes (Marcel) rather than trusting the client-declared type.
    # Adds errors to the record and returns false when anything fails.
    def validate_screenshots(report, files)
      config = BugReportsClient.config
      messages = []

      if files.size > config.max_screenshots
        messages << t("bug_reports_client.errors.too_many_screenshots", max: config.max_screenshots)
      end

      files.each do |file|
        detected_type = Marcel::MimeType.for(file.tempfile, name: file.original_filename, declared_type: file.content_type)
        unless config.screenshot_content_types.include?(detected_type)
          messages << t("bug_reports_client.errors.screenshot_type", filename: file.original_filename)
        end
        if file.size > config.max_screenshot_size
          messages << t("bug_reports_client.errors.screenshot_size", filename: file.original_filename, max_mb: config.max_screenshot_size / (1024 * 1024))
        end
      end

      return true if messages.empty?

      report.validate
      messages.each { |message| report.errors.add(:base, message) }
      false
    end

    # Minimal offset/limit pagination - deliberately no pagy/kaminari
    # dependency. Sets @page/@total_pages for the shared pagination partial.
    def paginate(scope)
      @page = [ params[:page].to_i, 1 ].max
      @total_pages = [ (scope.count / PER_PAGE.to_f).ceil, 1 ].max
      @page = @total_pages if @page > @total_pages
      scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    # Applies the active status and type filters to a bug reports relation.
    def filtered(scope)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(report_type: params[:report_type]) if params[:report_type].present?
      scope
    end

    # Status counts within the currently-selected type, so the tabs stay in
    # sync with the type filter (and vice versa for type_counts).
    def status_counts(scope)
      scope = scope.where(report_type: params[:report_type]) if params[:report_type].present?
      { all: scope.count, open: scope.open.count, closed: scope.closed.count }
    end

    def type_counts(scope)
      scope = scope.where(status: params[:status]) if params[:status].present?
      { all: scope.count, bug: scope.bug.count, feature: scope.feature.count }
    end

    # Dismisses a resolved-report alert. Removes the alert elements via Turbo
    # Streams and renders the overridable _after_dismiss hook so hosts can
    # update their own UI (e.g. a notification badge) in the same response.
    def dismiss_bug_report
      # Column write, not update!: dismissing must work even for reports that
      # would no longer pass validation (e.g. after a form-schema change).
      @bug_report.update_columns(dismissed_at: Time.current, updated_at: Time.current)

      @remaining = BugReport.where(user: bug_reports_current_user).resolved_and_undismissed

      respond_to do |format|
        format.turbo_stream do
          streams = [ turbo_stream.remove("bug_report_#{@bug_report.id}") ]
          streams << turbo_stream.remove("bug_report_alerts") if @remaining.empty?
          streams << render_to_string(partial: "bug_reports_client/shared/after_dismiss", formats: [ :turbo_stream ])

          render turbo_stream: streams
        end
        format.html do
          redirect_to fallback_root_path, notice: t("bug_reports_client.flashes.dismissed", type_noun: @bug_report.type_noun.capitalize)
        end
      end
    end

    # Host root if one exists, otherwise the engine's own index.
    def fallback_root_path
      main_app.respond_to?(:root_path) ? main_app.root_path : bug_reports_path
    end
  end
end
