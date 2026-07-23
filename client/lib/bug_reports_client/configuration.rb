module BugReportsClient
  # Holds all host-app configuration for the engine. Every setting has a
  # sensible default (mostly environment-variable backed) so a typical host
  # only needs to set `source` in its initializer:
  #
  #   BugReportsClient.configure do |config|
  #     config.source = "myapp"
  #   end
  #
  # Wording is intentionally NOT configured here - all user-facing copy lives
  # in i18n (see config/locales/en.yml) and form fields are defined in the
  # form schema YAML, so this class only carries behavioural settings.
  class Configuration
    # Connection to the bug-reports API.
    attr_accessor :api_url, :api_key, :webhook_secret

    # Identity of this app. `source` must match the ApiKey name registered on
    # the API and a key in its repo mapping. `app_host` is the public HTTPS
    # origin of this app, used to build the callback URL and screenshot links.
    attr_accessor :source, :app_host, :app_name

    # Where the engine is mounted, used to derive the default callback URL.
    attr_accessor :mount_path
    attr_writer :callback_url

    # Integration with the host's controllers and user model.
    # `authenticate_method` is the host method the engine calls to enforce
    # login. Set it to nil when the parent_controller already authenticates
    # globally (e.g. its own before_action :authenticate_user!, which the
    # engine inherits) so authentication does not run twice per request.
    attr_accessor :parent_controller, :current_user_method, :authenticate_method,
                  :user_class, :reporter_email_method, :reporter_name_method

    # Behavioural flags. `reporter_external` and `admin_check` are procs
    # receiving the current user; `ask_severity` hides the severity picker
    # (consumer-facing apps) and submits `default_severity` instead.
    attr_accessor :reporter_external, :admin_check, :ask_severity,
                  :default_severity, :screenshots_enabled, :max_screenshots,
                  :screenshot_content_types, :max_screenshot_size

    # Automatic error capture (Sentry-style 500 reporting). Opt-in per host;
    # `error_ignore` lists extra exception class names to skip (classes Rails
    # maps to non-5xx responses are skipped automatically), and the throttle
    # limits how often one fingerprint is posted from this app.
    attr_accessor :error_reporting_enabled, :error_ignore, :error_throttle_period

    # Optional overrides for the form definition and GitHub issue template.
    # When nil, the engine looks for config/bug_report_form.yml and
    # config/bug_report_issue.md in the host app, then falls back to its own
    # defaults.
    attr_accessor :form_schema_path, :issue_template_path

    def initialize
      @api_url = ENV.fetch("BUG_REPORT_API_URL", "http://localhost:3002/api")
      @api_key = ENV["BUG_REPORT_API_KEY"]
      @webhook_secret = ENV["BUG_REPORT_WEBHOOK_SECRET"]
      @app_host = ENV["APP_HOST"]
      @app_name = nil
      @source = nil
      @mount_path = "/bug_reports"
      @callback_url = nil
      @parent_controller = "::ApplicationController"
      @current_user_method = :current_user
      @authenticate_method = :authenticate_user!
      @user_class = "User"
      @reporter_email_method = :email
      @reporter_name_method = :name
      @reporter_external = ->(_user) { false }
      @admin_check = ->(_user) { false }
      @ask_severity = true
      @default_severity = "medium"
      @screenshots_enabled = true
      @max_screenshots = 5
      @screenshot_content_types = %w[image/png image/jpeg image/gif image/webp]
      @max_screenshot_size = 10 * 1024 * 1024
      @form_schema_path = nil
      @issue_template_path = nil
      @error_reporting_enabled = false
      @error_ignore = []
      @error_throttle_period = 300
    end

    # The URL the API calls back when a report's GitHub issue is closed.
    # Must be public HTTPS in production - the API refuses private hosts.
    def callback_url
      @callback_url || begin
        raise ConfigurationError, "BugReportsClient: set config.app_host (or APP_HOST) so the callback URL can be built" if app_host.blank?
        File.join(app_host, mount_path, "webhook")
      end
    end

    def source!
      raise ConfigurationError, "BugReportsClient: config.source is required (must match your API key name)" if source.blank?
      source
    end

    # Reporter attribute readers accept either a method name (symbol) or a
    # proc, so hosts without e.g. a `name` method can supply a lambda.
    def reporter_email_for(user)
      resolve(reporter_email_method, user)
    end

    def reporter_name_for(user)
      resolve(reporter_name_method, user)
    end

    def external_reporter?(user)
      !!reporter_external.call(user)
    end

    def admin?(user)
      !!admin_check.call(user)
    end

    private

    def resolve(method_or_proc, user)
      method_or_proc.respond_to?(:call) ? method_or_proc.call(user) : user.public_send(method_or_proc)
    end
  end
end
