module BugReportsClient
  # Builds the markdown description sent to the API (and so the GitHub issue
  # body) from a report's schema-driven answers.
  #
  # Two modes:
  #   - Template: if the host provides a markdown issue template (explicit
  #     config.issue_template_path or config/bug_report_issue.md), it is
  #     rendered with {{placeholder}} substitution. Available placeholders:
  #     every schema field key, plus {{title}}, {{report_type}}, {{severity}},
  #     {{reporter_name}}, {{app_name}} and {{screenshots}}.
  #   - Default: auto-generates a "## <field label>" section per answered
  #     field in schema order, prefixed with the severity line for bugs and
  #     suffixed with screenshot links.
  class DescriptionBuilder
    def initialize(bug_report, config: BugReportsClient.config, schema: BugReportsClient.form_schema)
      @bug_report = bug_report
      @config = config
      @schema = schema
    end

    def build
      template_path = resolve_template_path
      template_path ? render_template(template_path) : render_default
    end

    private

    def resolve_template_path
      explicit = @config.issue_template_path
      return explicit if explicit.present? && File.exist?(explicit)

      host_default = Rails.root.join("config", "bug_report_issue.md")
      host_default.exist? ? host_default : nil
    end

    def render_template(path)
      File.read(path).gsub(/\{\{\s*([a-z0-9_]+)\s*\}\}/i) { placeholder_value(Regexp.last_match(1)) }
    end

    def placeholder_value(key)
      case key
      when "title" then @bug_report.title.to_s
      when "report_type" then @bug_report.report_type.to_s
      when "severity" then @bug_report.severity.to_s
      when "reporter_name" then @config.reporter_name_for(@bug_report.user).to_s
      when "app_name" then app_name
      when "screenshots" then screenshot_links
      else
        @bug_report.response(key).to_s
      end
    end

    # Sections in schema order, skipping unanswered fields so the issue only
    # contains what the reporter actually filled in.
    def render_default
      sections = []
      sections << "**#{I18n.t('bug_reports_client.description.severity')}:** #{@bug_report.severity}" if @bug_report.bug? && @bug_report.severity.present?

      @schema.fields_for(@bug_report.report_type).each do |field|
        value = @bug_report.response(field.key)
        next if value.blank?

        sections << "## #{field.label_text}\n#{value}"
      end

      # Set server-side when the reporter linked a captured 500 - the
      # fingerprint cross-references the automatically-filed error issue.
      related = @bug_report.response("related_error")
      sections << "## #{I18n.t('bug_reports_client.description.related_error')}\n#{related}" if related.present?

      screenshots = screenshot_links
      sections << "## #{I18n.t('bug_reports_client.description.screenshots')}\n#{screenshots}" if screenshots.present?

      sections.join("\n\n")
    end

    # Markdown list of public screenshot URLs. Blob URLs are built against the
    # configured app host so they resolve from GitHub.
    def screenshot_links
      return "" unless @config.screenshots_enabled && @bug_report.screenshots.attached?

      @bug_report.screenshots.map do |screenshot|
        "- #{Rails.application.routes.url_helpers.rails_blob_url(screenshot, host: @config.app_host)}"
      end.join("\n")
    end

    def app_name
      @config.app_name.presence || Rails.application.class.module_parent_name
    end
  end
end
