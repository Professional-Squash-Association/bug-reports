# Stores bug report submissions from PSA applications.
# Each report is linked to a source app and maps to a GitHub repository
# where an issue is created asynchronously.
class BugReport < ApplicationRecord
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[pending closed].freeze

  validates :title, :description, :source, :callback_url, presence: true
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
end
