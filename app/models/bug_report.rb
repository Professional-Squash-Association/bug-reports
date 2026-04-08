# Stores bug report submissions from PSA applications.
# Each report is linked to a source app and maps to a GitHub repository
# where an issue is created asynchronously.
class BugReport < ApplicationRecord
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[pending closed].freeze

  validates :title, :description, :source, :callback_url, presence: true
  validate :callback_url_must_be_valid_https
  validates :reporter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validate :source_must_be_mapped

  def resolved_repo
    RepoMapping.repo_for(source)
  end

  private

  def source_must_be_mapped
    errors.add(:source, "is not a recognised source") if source.present? && !RepoMapping.valid_source?(source)
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
