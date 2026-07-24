# Configuration for bug_reports_client. Most settings default from
# environment variables (BUG_REPORT_API_URL, BUG_REPORT_API_KEY,
# BUG_REPORT_WEBHOOK_SECRET, APP_HOST) - see the gem README for the full
# reference.
BugReportsClient.configure do |config|
  # REQUIRED: must match this app's API key name on the bug-reports API and a
  # key in its repo mapping.
  config.source = "<%= Rails.application.class.module_parent_name.underscore %>"

  # The public HTTPS origin of this app, used for the closure callback URL and
  # screenshot links in GitHub issues. Defaults to ENV["BUG_REPORT_APP_HOST"],
  # then ENV["APP_HOST"] - set it explicitly if APP_HOST serves other purposes.
  # config.app_host = "https://myapp.example.com"

  # Who counts as an admin (can see /bug_reports/all).
  # config.admin_check = ->(user) { user.admin? }

  # Whether reports come from outside your team (shown on the GitHub issue).
  # config.reporter_external = ->(user) { true }

  # Consumer-facing apps often hide the severity picker; bugs then submit
  # config.default_severity ("medium") automatically.
  # config.ask_severity = false

  # Screenshot uploads need an Active Storage service whose URLs are publicly
  # reachable (e.g. S3) - otherwise disable them.
  # config.screenshots_enabled = false

  # Reporter attributes, if your user model differs from the defaults
  # (User#email and User#name). Symbols or procs are accepted.
  # config.reporter_name_method = ->(user) { "#{user.first_name} #{user.last_name}" }
end
