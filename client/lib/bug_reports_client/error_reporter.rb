require "digest"

module BugReportsClient
  # Subscribes to the Rails error reporter and turns unhandled exceptions
  # (real 500s) into error reports on the central API, which files one GitHub
  # issue per distinct error. Sentry-style basics without the Sentry:
  #
  #   - Only unhandled errors are captured, and only ones Rails would answer
  #     with a 5xx (RecordNotFound and friends map to 4xx and are skipped).
  #   - Errors are fingerprinted by exception class + the top application
  #     backtrace frame (line numbers stripped, so deploys that shift code
  #     around keep the same fingerprint).
  #   - A cache-based throttle stops an error storm flooding the API; the
  #     API deduplicates authoritatively by fingerprint regardless.
  #
  # Enable per host with config.error_reporting_enabled = true.
  class ErrorReporter
    BACKTRACE_LINES = 20

    # Called by Rails.error for every reported error. Must never raise -
    # error reporting failing inside a failing request would mask the
    # original problem.
    def report(error, handled:, severity: nil, context: {}, source: nil)
      return if handled
      return unless BugReportsClient.config.error_reporting_enabled
      return if ignored?(error)

      fingerprint = self.class.fingerprint_for(error)
      record_user_event(error, fingerprint, context)

      return unless claim!(fingerprint)

      ReportErrorJob.perform_later(
        "fingerprint" => fingerprint,
        "exception_class" => error.class.name,
        "message" => error.message.to_s.truncate(2_000),
        "backtrace" => cleaned_backtrace(error),
        "occurred_at" => Time.current.iso8601
      )
    rescue StandardError => e
      Rails.logger.error "BugReportsClient: error reporter failed: #{e.class}: #{e.message}"
      nil
    end

    # Stable identity for "the same error": class + top application frame
    # with the line number stripped, so unrelated code changes moving lines
    # around do not spawn new issues.
    def self.fingerprint_for(error)
      frame = Rails.backtrace_cleaner.clean(error.backtrace || []).first.to_s
      frame = frame.sub(/:\d+:in /, ":in ")
      Digest::SHA256.hexdigest("#{error.class.name}|#{frame}")[0, 16]
    end

    private

    # Skips exception classes Rails maps to non-5xx responses (RecordNotFound
    # -> 404 etc), plus any classes the host lists in config.error_ignore.
    def ignored?(error)
      return true if BugReportsClient.config.error_ignore.include?(error.class.name)

      status = ActionDispatch::ExceptionWrapper.rescue_responses[error.class.name]
      status.present? && Rack::Utils.status_code(status) < 500
    end

    # One report per fingerprint per throttle period, enforced through the
    # host's cache. A cache without unless_exist support just means more
    # posts - the API deduplicates anyway.
    def claim!(fingerprint)
      Rails.cache.write(
        "bug_reports_client:error:#{fingerprint}",
        true,
        unless_exist: true,
        expires_in: BugReportsClient.config.error_throttle_period
      )
    end

    def cleaned_backtrace(error)
      Rails.backtrace_cleaner.clean(error.backtrace || []).first(BACKTRACE_LINES)
    end

    # Attributes the error to the signed-in user who hit it (id set by
    # ErrorContext), so the report form can offer "did it relate to this
    # error?". Recorded on EVERY occurrence - unlike the API post, which is
    # throttled - and best-effort: failures are swallowed.
    def record_user_event(error, fingerprint, context)
      user_id = context[:bug_reports_user_id]
      return if user_id.blank?

      ErrorEvent.record!(
        user_id: user_id,
        fingerprint: fingerprint,
        exception_class: error.class.name,
        message: error.message,
        activity: activity_from(context),
        occurred_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.debug { "BugReportsClient: error event not recorded (#{e.class}: #{e.message})" }
      nil
    end

    # Human-readable "what the user was doing" - shown to users on the report
    # form in place of exception details. Built from the controller/action at
    # capture time: "viewing invoices", "saving changes to players".
    def activity_from(context)
      controller = context[:bug_reports_controller]
      return nil if controller.blank?

      verb = I18n.t(
        "bug_reports_client.activities.#{context[:bug_reports_action]}",
        default: I18n.t("bug_reports_client.activities.other")
      )
      "#{verb} #{controller.to_s.humanize.downcase}"
    end
  end
end
