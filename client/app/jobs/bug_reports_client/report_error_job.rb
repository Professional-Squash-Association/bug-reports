module BugReportsClient
  # Posts a captured error to the central API in the background, so the
  # failing request is never slowed down (or broken further) by reporting.
  # No retries: the API deduplicates by fingerprint and errors tend to recur,
  # so a lost report costs little - a retry storm during an outage costs more.
  class ReportErrorJob < ActiveJob::Base
    queue_as :default

    def perform(attributes)
      title = "[Error] #{attributes['exception_class']}: #{attributes['message']}".truncate(150)

      result = ApiClient.new.create_error_report(
        title: title,
        description: build_description(attributes),
        fingerprint: attributes["fingerprint"],
        occurred_at: attributes["occurred_at"]
      )

      Rails.logger.warn "BugReportsClient: error report not accepted: #{result.message}" unless result.success?
    end

    private

    # Markdown for the GitHub issue: exception, message, fingerprint and a
    # trimmed application backtrace.
    def build_description(attributes)
      <<~MARKDOWN
        ## #{attributes['exception_class']}

        ```
        #{attributes['message']}
        ```

        **Fingerprint:** `#{attributes['fingerprint']}` | **First captured:** #{attributes['occurred_at']}

        ### Application backtrace

        ```
        #{Array(attributes['backtrace']).join("\n")}
        ```
      MARKDOWN
    end
  end
end
