module BugReportsClient
  # Local record of a report submitted to the central bug-reports API. Stores
  # the report for user viewing/editing; the schema-driven answers live in the
  # `responses` JSON column keyed by field name. Closure updates arrive via
  # the signed webhook and flip status to closed, which surfaces the
  # resolved-report alert until the user dismisses it.
  class BugReport < ApplicationRecord
    self.table_name = "bug_reports"

    belongs_to :user, class_name: BugReportsClient.config.user_class

    has_many_attached :screenshots

    enum :status, { open: "open", closed: "closed" }
    enum :severity, { low: "low", medium: "medium", high: "high", critical: "critical" }
    enum :report_type, { bug: "bug", feature: "feature" }

    validates :title, presence: true
    validates :report_type, presence: true
    validates :remote_bug_report_id, uniqueness: true, allow_nil: true
    # The API requires a severity for bugs. When the host hides the picker
    # (ask_severity false) the controller fills in the default before saving.
    validates :severity, presence: true, if: :bug?

    validate :required_responses_present
    validate :screenshot_limit

    scope :undismissed, -> { where(dismissed_at: nil) }
    scope :resolved_and_undismissed, -> { closed.undismissed }

    # Reads a single schema-field answer. Keys are always stored as strings.
    def response(key)
      (responses || {})[key.to_s]
    end

    # Merges new answers in rather than replacing, so partial updates (e.g. a
    # type switch that only submits the visible fields) keep earlier answers.
    def responses=(new_responses)
      super((responses || {}).merge((new_responses || {}).stringify_keys))
    end

    # A bug's severity and a feature's `priority` field are the same "how
    # important is this" rating shown in one list column.
    def importance
      feature? ? response("priority").presence || severity : severity
    end

    # Human-readable noun for user-facing copy ("bug report" / "feature request").
    def type_noun
      I18n.t("bug_reports_client.type_nouns.#{report_type.presence || 'bug'}")
    end

    private

    # Enforces the schema's required fields for the selected report type.
    # Checkboxes must be ticked; everything else must be present.
    def required_responses_present
      return if report_type.blank?

      BugReportsClient.form_schema.required_fields(report_type).each do |field|
        value = response(field.key)
        missing = field.checkbox? ? !ActiveModel::Type::Boolean.new.cast(value) : value.blank?
        errors.add(:base, I18n.t("bug_reports_client.errors.required_field", field: field.label_text)) if missing
      end
    end

    def screenshot_limit
      max = BugReportsClient.config.max_screenshots
      if screenshots.count > max
        errors.add(:base, I18n.t("bug_reports_client.errors.too_many_screenshots", max: max))
      end
    end
  end
end
