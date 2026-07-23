# Bearer token authentication for applications calling this API.
# Each key identifies one consuming app: a unique API token for
# authentication, a webhook secret used to sign closure callback payloads
# sent back to the app, and the GitHub repository where the app's reports
# are filed as issues.
#
# Onboard a new app with:
#   ApiKey.create!(name: "myapp", github_repo: "my-org/myapp")
class ApiKey < ApplicationRecord
  before_create :generate_secrets

  validates :name, presence: true, uniqueness: true
  validates :token, uniqueness: true
  validates :webhook_secret, uniqueness: true
  validates :github_repo, presence: true, format: {
    with: %r{\A[\w.-]+/[\w.-]+\z},
    message: "must be in owner/repository form"
  }

  # The GitHub repository for a source app, or nil if the source is unknown.
  def self.repo_for(source)
    find_by(name: source)&.github_repo
  end

  private

  def generate_secrets
    self.token = SecureRandom.hex(32)
    self.webhook_secret = SecureRandom.hex(32)
  end
end
