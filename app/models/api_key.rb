# Bearer token authentication for PSA applications calling this API.
# Generate a key per app via: ApiKey.create!(name: "secure")
class ApiKey < ApplicationRecord
  before_create :generate_token

  validates :name, presence: true
  validates :token, uniqueness: true

  private

  def generate_token
    self.token = SecureRandom.hex(32)
  end
end
