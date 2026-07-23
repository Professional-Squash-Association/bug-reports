# Stores bug report submissions from consuming applications.
# Each report is linked to a source app (an ApiKey record) and maps to that
# app's GitHub repository, where an issue is created asynchronously.
#
# Three report types: user-submitted bugs and features (which carry reporter
# details and a callback_url for closure notifications), and automatic error
# reports (500 captures) which are machine-generated - no reporter, no
# callback, deduplicated by fingerprint instead.
class BugReport < ApplicationRecord
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[pending closed].freeze
  REPORT_TYPES = %w[bug feature error].freeze

  validates :title, :description, :source, presence: true
  validates :callback_url, presence: true, unless: :error?
  validate :callback_url_must_be_valid_https
  validates :reporter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, unless: :error?
  validates :severity, inclusion: { in: SEVERITIES }, allow_blank: true
  validates :severity, presence: true, if: :bug?
  validates :status, inclusion: { in: STATUSES }
  validates :report_type, inclusion: { in: REPORT_TYPES }
  validates :fingerprint, presence: true, if: :error?
  validate :source_must_be_mapped

  # The open error report matching a fingerprint, if any - repeats bump this
  # record instead of creating duplicate issues.
  scope :open_error_for, ->(source, fingerprint) {
    where(report_type: "error", source: source, fingerprint: fingerprint, status: "pending")
  }

  def resolved_repo
    ApiKey.repo_for(source)
  end

  def bug?
    report_type == "bug"
  end

  def feature?
    report_type == "feature"
  end

  def error?
    report_type == "error"
  end

  # Records another occurrence of an already-tracked error.
  def record_occurrence!(occurred_at)
    update!(occurrence_count: occurrence_count + 1, last_occurred_at: occurred_at)
  end

  private

  def source_must_be_mapped
    errors.add(:source, "is not a recognised source") if source.present? && ApiKey.repo_for(source).blank?
  end

  def callback_url_must_be_valid_https
    return if callback_url.blank?

    uri = URI.parse(callback_url)
    errors.add(:callback_url, "must use HTTPS") unless uri.scheme == "https"
    errors.add(:callback_url, "must have a valid host") if uri.host.blank?
  rescue URI::InvalidURIError
    errors.add(:callback_url, "is not a valid URL")
  end
end
