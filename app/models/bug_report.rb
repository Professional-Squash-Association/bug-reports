# Stores bug report submissions from PSA applications.
# Each report is linked to a source app and maps to a GitHub repository
# where an issue is created asynchronously.
class BugReport < ApplicationRecord
  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[pending created failed closed].freeze

  validates :title, presence: true
  validates :description, presence: true
  validates :source, presence: true
  validates :reporter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }

  # Resolves the GitHub repository for this report based on its source app
  def resolved_repo
    RepoMapping.repo_for(source)
  end
end
