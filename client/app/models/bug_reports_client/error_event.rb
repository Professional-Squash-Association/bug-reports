module BugReportsClient
  # A captured 500 attributed to the signed-in user who hit it. Surfaced on
  # the report form ("did your problem relate to this error?") so user bug
  # reports can reference the automatically-filed error issue by fingerprint.
  # Events are short-lived working data - old ones are pruned on write.
  class ErrorEvent < ApplicationRecord
    self.table_name = "bug_report_error_events"

    RETENTION = 30 * 24 * 60 * 60 # seconds; errors older than this are pruned

    belongs_to :user, class_name: BugReportsClient.config.user_class

    scope :recent_first, -> { order(occurred_at: :desc) }
    scope :since, ->(time) { where(occurred_at: time..) }

    # Records an occurrence for a user and prunes their stale events.
    def self.record!(user_id:, fingerprint:, exception_class:, message:, occurred_at:, activity: nil)
      where(user_id: user_id).where(occurred_at: ...(Time.current - RETENTION)).delete_all

      create!(
        user_id: user_id,
        fingerprint: fingerprint,
        exception_class: exception_class,
        message: message.to_s.truncate(200),
        activity: activity,
        occurred_at: occurred_at
      )
    end

    # Technical one-liner for the GitHub issue markdown - never shown to
    # end users.
    def summary
      "#{exception_class}: #{message}".truncate(110)
    end

    # What the user sees on the report form: what they were doing, not the
    # exception ("something went wrong while viewing invoices").
    def user_facing_description
      if activity.present?
        I18n.t("bug_reports_client.form.related_error.option_with_activity", activity: activity)
      else
        I18n.t("bug_reports_client.form.related_error.option_generic")
      end
    end
  end
end
