# Notifies the originating PSA application when a bug report's GitHub issue is closed.
# Sends a signed POST request to the callback URL so the app can update the user.
# The payload is signed with the per-app webhook secret from the ApiKey record,
# allowing each consuming app to verify callbacks independently.
# Retries up to 5 times with polynomial backoff on failure.
require "net/http"

class NotifySourceAppJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(bug_report_id)
    bug_report = BugReport.find(bug_report_id)
    return unless bug_report.callback_url.present?

    api_key = ApiKey.find_by(name: bug_report.source)
    raise "No API key found for source: #{bug_report.source}" unless api_key

    payload = {
      bug_report_id: bug_report.id,
      title: bug_report.title,
      source: bug_report.source,
      github_repo: bug_report.github_repo,
      github_issue_number: bug_report.github_issue_number,
      reporter_email: bug_report.reporter_email,
      status: "closed"
    }.to_json

    # Sign with the per-app webhook secret so each app can verify independently
    signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      api_key.webhook_secret,
      payload
    )

    uri = URI.parse(bug_report.callback_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "X-Signature" => "sha256=#{signature}"
    })
    request.body = payload

    response = http.request(request)
    raise "Callback failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end
end
