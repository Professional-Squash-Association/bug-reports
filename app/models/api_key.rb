# Bearer token authentication for PSA applications calling this API.
# Each key has a unique API token for authentication and a webhook secret
# used to sign closure callback payloads sent back to the source app.
# Generate a key per app via: ApiKey.create!(name: "secure")
class ApiKey < ApplicationRecord
  before_create :generate_secrets

  validates :name, presence: true
  validates :token, uniqueness: true
  validates :webhook_secret, uniqueness: true

  private

  def generate_secrets
    self.token = SecureRandom.hex(32)
    self.webhook_secret = SecureRandom.hex(32)
  end
end
