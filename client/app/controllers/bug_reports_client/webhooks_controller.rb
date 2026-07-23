module BugReportsClient
  # Receives closure notifications from the bug-reports API when a report's
  # GitHub issue is closed. Deliberately inherits from ActionController::Base
  # (not the host's ApplicationController) so no host auth chain or callbacks
  # interfere with machine-to-machine requests. Payloads are verified with a
  # per-app HMAC-SHA256 signature before anything is touched; when the sender
  # includes a signed timestamp, stale (replayed) callbacks are rejected too.
  class WebhooksController < ActionController::Base
    class SignatureError < StandardError; end

    # Callback payloads are small JSON documents - anything bigger is bogus.
    MAX_BODY_BYTES = 1_048_576

    # How old a timestamped callback may be before it is treated as a replay.
    TIMESTAMP_TOLERANCE = 5 * 60

    skip_forgery_protection

    # POST /webhook
    def receive
      return head :content_too_large if request.content_length.to_i > MAX_BODY_BYTES

      raw_body = request.raw_post
      verify_signature!(raw_body)

      payload = JSON.parse(raw_body)
      Rails.logger.info "BugReportsClient: report closed: ##{payload['bug_report_id']} - #{payload['title']}"

      # Mark the local record closed so the reporter sees the resolved alert.
      # A bare column write, not update!: legacy reports (or ones predating a
      # form-schema change that added required fields) must still be closable.
      local_report = BugReport.find_by(remote_bug_report_id: payload["bug_report_id"])
      if local_report
        local_report.update_columns(status: "closed", updated_at: Time.current)
      else
        Rails.logger.warn "BugReportsClient: no local report for remote ID #{payload['bug_report_id']}"
      end

      head :ok
    rescue SignatureError
      head :unauthorized
    rescue JSON::ParserError => e
      Rails.logger.error "BugReportsClient: webhook parse error: #{e.message}"
      head :unprocessable_entity
    end

    private

    # Verifies the HMAC-SHA256 signature using the per-app webhook secret.
    # Preferred scheme: X-Timestamp + X-Signature-Timestamped, where the HMAC
    # covers "<timestamp>.<body>" and the timestamp must be recent (replay
    # protection). Falls back to the legacy body-only X-Signature when no
    # timestamp headers are sent.
    def verify_signature!(raw_body)
      secret = BugReportsClient.config.webhook_secret
      if secret.blank?
        Rails.logger.error "BugReportsClient: webhook secret not configured"
        raise SignatureError, "Webhook secret not configured"
      end

      if request.headers["X-Timestamp"].present?
        verify_timestamped!(secret, raw_body)
      else
        verify_legacy!(secret, raw_body)
      end
    end

    def verify_timestamped!(secret, raw_body)
      timestamp = request.headers["X-Timestamp"].to_s
      unless timestamp.match?(/\A\d+\z/) && (Time.current.to_i - timestamp.to_i).abs <= TIMESTAMP_TOLERANCE
        Rails.logger.warn "BugReportsClient: webhook timestamp stale or malformed"
        raise SignatureError, "Stale timestamp"
      end

      signature = request.headers["X-Signature-Timestamped"].to_s
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{raw_body}")}"

      unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)
        Rails.logger.warn "BugReportsClient: webhook timestamped signature mismatch"
        raise SignatureError, "Invalid signature"
      end
    end

    def verify_legacy!(secret, raw_body)
      signature = request.headers["X-Signature"].to_s
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"

      unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)
        Rails.logger.warn "BugReportsClient: webhook signature mismatch"
        raise SignatureError, "Invalid signature"
      end
    end
  end
end
