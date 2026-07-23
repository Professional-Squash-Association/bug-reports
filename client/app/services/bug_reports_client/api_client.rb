require "net/http"
require "json"

module BugReportsClient
  # HTTP client for the central bug-reports API. Self-contained (no host
  # dependencies): Bearer-token auth, JSON encoding, timeout retries, and
  # Result objects so controllers can branch on success without rescuing.
  class ApiClient
    class ApiError < StandardError; end
    class AuthenticationError < ApiError; end
    class ValidationError < ApiError; end

    # Simple success/failure wrapper returned by the public methods.
    Result = Struct.new(:success, :message, :data) do
      def success? = !!success
    end

    def initialize(config: BugReportsClient.config)
      @config = config
      raise AuthenticationError, "BUG_REPORT_API_KEY not configured" if @config.api_key.blank?
    end

    # Submit a new report. The description carries all formatted details
    # (answers, reporter, screenshots) as markdown for the GitHub issue.
    # POST /api/bug_reports
    def create_bug_report(title:, description:, reporter_email:, severity: nil, report_type: "bug", reporter_name: nil, reporter_external: false)
      body = {
        bug_report: {
          title: prefixed_title(title, report_type),
          description: description,
          severity: severity,
          report_type: report_type,
          reporter_email: reporter_email,
          reporter_name: reporter_name,
          reporter_external: reporter_external,
          source: @config.source!,
          callback_url: @config.callback_url
        }
      }

      response = post("/bug_reports", body)
      Result.new(true, "Report submitted successfully", response)
    rescue ValidationError => e
      Result.new(false, "Validation error: #{e.message}")
    rescue => e
      # Full details go to the log only - raw exception text can leak
      # internal hosts/URLs into user-facing flash messages.
      Rails.logger.error "BugReportsClient: failed to create bug report: #{e.message}"
      Result.new(false, I18n.t("bug_reports_client.flashes.submit_failed"))
    end

    # Submit an automatic error report (500 capture). The API deduplicates
    # by fingerprint - repeats of an open error bump its occurrence count.
    # POST /api/error_reports
    def create_error_report(title:, description:, fingerprint:, occurred_at:, severity: "high")
      body = {
        error_report: {
          title: title,
          description: description,
          fingerprint: fingerprint,
          occurred_at: occurred_at,
          severity: severity,
          source: @config.source!
        }
      }

      response = post("/error_reports", body)
      Result.new(true, "Error report submitted", response)
    rescue ValidationError => e
      Result.new(false, "Validation error: #{e.message}")
    rescue => e
      Rails.logger.error "BugReportsClient: failed to create error report: #{e.message}"
      Result.new(false, I18n.t("bug_reports_client.flashes.submit_failed"))
    end

    # Update an existing report on the API.
    # PATCH /api/bug_reports/:id
    def update_bug_report(id, title:, description:, severity: nil, report_type: "bug")
      body = {
        bug_report: {
          title: prefixed_title(title, report_type),
          description: description,
          severity: severity,
          report_type: report_type
        }
      }

      response = patch("/bug_reports/#{id}", body)
      Result.new(true, "Report updated successfully", response)
    rescue ValidationError => e
      Result.new(false, "Validation error: #{e.message}")
    rescue => e
      Rails.logger.error "BugReportsClient: failed to update bug report #{id}: #{e.message}"
      Result.new(false, I18n.t("bug_reports_client.flashes.submit_failed"))
    end

    private

    # Issue titles are prefixed so GitHub issues are scannable at a glance.
    def prefixed_title(title, report_type = "bug")
      prefix = report_type == "feature" ? "Feature" : "Bug"
      "[#{prefix}]: #{title}"
    end

    def post(path, body)
      request = Net::HTTP::Post.new(build_uri(path))
      request.body = body.to_json
      execute(request)
    end

    def patch(path, body)
      request = Net::HTTP::Patch.new(build_uri(path))
      request.body = body.to_json
      execute(request)
    end

    def build_uri(path)
      URI("#{@config.api_url}#{path}")
    end

    # Executes with auth headers and up to two retries on timeouts.
    def execute(request, retry_count: 0)
      request["Authorization"] = "Bearer #{@config.api_key}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"

      uri = request.uri
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30) do |http|
        http.request(request)
      end

      handle_response(response)
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      if retry_count < 2
        sleep(2**retry_count)
        execute(request, retry_count: retry_count + 1)
      else
        raise ApiError, "Request timeout after #{retry_count + 1} attempts: #{e.message}"
      end
    rescue ApiError
      raise
    rescue => e
      raise ApiError, "Request failed: #{e.message}"
    end

    def handle_response(response)
      case response.code.to_i
      when 200..299
        JSON.parse(response.body.to_s.force_encoding("UTF-8"))
      when 401
        raise AuthenticationError, "Invalid API key"
      when 403
        raise AuthenticationError, "API key not permitted for source #{@config.source.inspect}"
      when 422
        error_data = parse_body(response)
        raise ValidationError, extract_errors(error_data)
      else
        error_data = parse_body(response)
        raise ApiError, "API error (#{response.code}): #{error_data['message'] || error_data['error'] || response.body}"
      end
    end

    def parse_body(response)
      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      {}
    end

    def extract_errors(error_data)
      messages = error_data["errors"] || error_data["messages"] || [ error_data["message"] || error_data["error"] || "Validation failed" ]
      Array(messages).join(", ")
    end
  end
end
