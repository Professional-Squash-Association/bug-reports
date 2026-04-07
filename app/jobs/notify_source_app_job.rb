# Notifies the originating PSA application when a bug report's GitHub issue is closed.
# Sends a signed POST request to the callback URL so the app can update the user.
# Retries up to 5 times with polynomial backoff on failure.
require "net/http"

class NotifySourceAppJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(bug_report_id)
    bug_report = BugReport.find(bug_report_id)
    return unless bug_report.callback_url.present?

    # Do we need all these fields in the payload?
    payload = {
      bug_report_id: bug_report.id,
      title: bug_report.title,
      source: bug_report.source,
      github_repo: bug_report.github_repo,
      github_issue_number: bug_report.github_issue_number,
      reporter_email: bug_report.reporter_email,
      status: "closed"
    }.to_json

    signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      ENV.fetch("WEBHOOK_SECRET", "dev-secret"),
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
