require "openssl"
require "base64"

# Builds an Octokit client that authenticates as the "PSA Reporter" GitHub
# App installation, so issues are attributed to the app (a bot) rather than a
# personal account. Falls back to a personal access token when the app is not
# configured (e.g. local development), so nothing breaks before the app exists.
#
# Configure with GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID and
# GITHUB_APP_PRIVATE_KEY (the PEM). Without them, GITHUB_TOKEN is used.
class GithubApp
  # A GitHub App JWT may live at most 10 minutes; ask for 9 to allow clock skew.
  JWT_TTL = 9 * 60

  def self.client
    new.client
  end

  def client
    return Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN")) unless configured?

    Octokit::Client.new(access_token: installation_token)
  end

  private

  def configured?
    ENV["GITHUB_APP_ID"].present?
  end

  # Exchange a short-lived app JWT for an installation access token (valid ~1h).
  def installation_token
    app = Octokit::Client.new(bearer_token: app_jwt)
    app.create_app_installation_access_token(ENV.fetch("GITHUB_APP_INSTALLATION_ID")).token
  end

  # A GitHub App JWT: an RS256-signed token identifying the app itself.
  def app_jwt
    now = Time.now.to_i
    header = encode(alg: "RS256", typ: "JWT")
    payload = encode(iat: now - 60, exp: now + JWT_TTL, iss: ENV.fetch("GITHUB_APP_ID"))
    signing_input = "#{header}.#{payload}"
    signature = private_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
    "#{signing_input}.#{base64url(signature)}"
  end

  def private_key
    OpenSSL::PKey::RSA.new(ENV.fetch("GITHUB_APP_PRIVATE_KEY"))
  end

  def encode(hash)
    base64url(JSON.dump(hash))
  end

  def base64url(bytes)
    Base64.urlsafe_encode64(bytes, padding: false)
  end
end
