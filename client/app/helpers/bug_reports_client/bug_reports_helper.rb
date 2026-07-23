module BugReportsClient
  # View helpers for the engine's own pages, plus `bug_report_alerts` which is
  # exposed to host layouts so resolved-report notifications can be rendered
  # with a single line: <%= bug_report_alerts %>
  module BugReportsHelper
    # Renders dismissable "your report has been resolved" alerts for the
    # signed-in user. Returns nil quickly when signed out or nothing resolved,
    # so it is safe on every page including public ones.
    def bug_report_alerts
      user = alerts_user
      return if user.nil?

      resolved = BugReportsClient::BugReport.where(user: user).resolved_and_undismissed.order(created_at: :desc)
      return if resolved.empty?

      render "bug_reports_client/shared/alerts", resolved_bug_reports: resolved
    end

    # Pill used for the type filter (All types / Bugs / Features). When
    # active, each type carries its own accent colour to match the row badges.
    def report_type_pill_class(active, type = nil)
      base = "inline-flex items-center gap-1 px-3 py-1 rounded-full border text-sm font-medium transition-colors"
      return "#{base} bg-white text-slate-500 border-slate-200 hover:text-slate-700 hover:border-slate-300" unless active

      case type
      when "bug" then "#{base} bg-rose-100 text-rose-700 border-rose-200"
      when "feature" then "#{base} bg-indigo-100 text-indigo-700 border-indigo-200"
      else "#{base} bg-slate-700 text-white border-slate-700"
      end
    end

    # Shared input styling for the default form - one place to tweak the look
    # of every generated field.
    def brc_input_classes
      "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " \
      "placeholder:text-slate-400 focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500 " \
      "disabled:bg-slate-100 disabled:text-slate-500"
    end

    def brc_label_classes
      "block text-xs font-medium text-slate-500 uppercase tracking-wide mb-1"
    end

    private

    # The current user as seen from the HOST's context (this helper runs in
    # host layouts). Alerts are cosmetic, so ANY failure resolving the user -
    # a missing method, or e.g. Devise raising outside a real request
    # (mailer previews, ActionController.renderer) - means "no alerts", never
    # a broken page.
    def alerts_user
      method = BugReportsClient.config.current_user_method
      return nil unless controller.respond_to?(method, true)

      controller.send(method)
    rescue StandardError => e
      Rails.logger.debug { "BugReportsClient: bug_report_alerts skipped (#{e.class}: #{e.message})" }
      nil
    end
  end
end
