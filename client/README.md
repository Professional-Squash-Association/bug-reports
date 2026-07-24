# bug_reports_client

A mountable Rails engine that adds a complete bug-and-feature reporting flow
to your app, backed by a central [bug-reports API](../README.md) that files
GitHub issues and calls back when they are closed.

What your users get:

- A polished **report form** with a bug/feature toggle, driven entirely by a
  YAML schema you can customise per app - fields, types, required flags,
  sections and wording.
- **Screenshot uploads** (Active Storage, optional).
- A **"My Reports"** page tracking the status of everything they've filed,
  plus an admin-only "All Reports" view.
- **Resolved alerts**: when the GitHub issue is closed, a signed webhook flips
  the local record and the reporter sees a dismissable "your report has been
  resolved" banner.

Requirements: Rails >= 8.0, Turbo/Stimulus via importmap-rails, Tailwind CSS
(for the default views - or copy the views and style them however you like).

## Installation

```ruby
# Gemfile
gem "bug_reports_client", github: "Professional-Squash-Association/bug-reports", glob: "client/*.gemspec"
```

```bash
bundle install
bin/rails g bug_reports_client:install
bin/rails bug_reports_client:install:migrations && bin/rails db:migrate
```

The install generator creates `config/initializers/bug_reports_client.rb`,
mounts the engine at `/bug_reports`, and copies the default form schema to
`config/bug_report_form.yml` ready to customise. It prints the remaining
checklist:

```ruby
# app/models/user.rb
include BugReportsClient::Reporter
```

```erb
<%# somewhere in your layout %>
<%= link_to "Report a bug", bug_reports_client.new_bug_report_path %>
<%= bug_report_alerts %>
```

Environment variables (or set the equivalents in the initializer):

| Variable | Purpose |
|---|---|
| `BUG_REPORT_API_URL` | Base URL of the bug-reports API, e.g. `https://bugs.example.com/api` |
| `BUG_REPORT_API_KEY` | This app's API token (Bearer auth) |
| `BUG_REPORT_WEBHOOK_SECRET` | This app's webhook secret (HMAC verification of closure callbacks) |
| `BUG_REPORT_APP_HOST` | Public HTTPS origin of this app (callback URL + screenshot links). Falls back to `APP_HOST`; prefer this or `config.app_host` if `APP_HOST` serves other purposes |

On the API side, the app needs an `ApiKey` record and an entry in
`config/repo_mapping.yml` mapping its `source` name to a GitHub repository.

## Configuration

Everything lives in the initializer. Only `source` is required; the rest have
sensible defaults:

```ruby
BugReportsClient.configure do |config|
  config.source = "myapp"                 # must match the API key name

  # Host integration (defaults shown)
  config.parent_controller = "::ApplicationController"
  config.current_user_method = :current_user
  config.authenticate_method = :authenticate_user!
  config.user_class = "User"
  config.reporter_email_method = :email   # symbol or ->(user) { ... }
  config.reporter_name_method = :name

  # Behaviour
  config.admin_check = ->(user) { user.admin? }   # gates /bug_reports/all
  config.reporter_external = ->(user) { false }   # shown on the GitHub issue
  config.ask_severity = true               # false hides the picker...
  config.default_severity = "medium"       # ...and submits this for bugs
  config.screenshots_enabled = true        # needs publicly reachable storage
  config.max_screenshots = 5

  # Connection (default from ENV as above)
  # config.api_url / config.api_key / config.webhook_secret / config.app_host
  # config.callback_url                    # override the derived callback URL
  # config.mount_path = "/bug_reports"     # if you mount somewhere else
  # config.app_name = "My App"             # {{app_name}} in issue templates
end
```

## Customising the form

`config/bug_report_form.yml` defines the fields per report type:

```yaml
bug:
  - field: what_happened
    type: textarea          # text | textarea | select | checkbox
    required: true
    section: the_problem    # starts a new card; heading via i18n or humanised
    rows: 4
  - field: browser
    type: select
    options: [Chrome, Safari, Firefox, Other]      # or {value:, label:} pairs
feature:
  - field: problem
    type: textarea
    required: true
```

Delete the file to fall back to the engine's default schema (a
well-rounded bug/feature form). Define only one report type and the
bug/feature toggle disappears.

Answers are stored in a JSON `responses` column, validated server-side from
the same schema (required flags, and only schema-declared keys are permitted).

### Wording

All copy is i18n under the `bug_reports_client` namespace - override any
subset in your own locale files, no view copying needed:

```yaml
en:
  bug_reports_client:
    new:
      heading: "Report an issue"
    fields:
      what_happened:
        label: "What happened?"
        placeholder: "Tell us what went wrong"
```

Inline `label`/`placeholder`/`help` keys in the schema win over i18n.

### GitHub issue body

By default the issue body is generated from the schema: a `## <label>` section
per answered field, a severity line for bugs, and screenshot links. To control
it yourself, create `config/bug_report_issue.md` (the install generator drops
an `.example` next to it) using `{{field}}` placeholders - every schema field
key plus `{{title}}`, `{{report_type}}`, `{{severity}}`, `{{reporter_name}}`,
`{{app_name}}` and `{{screenshots}}`.

### Views

The default views are plain Tailwind. To restyle:

```bash
bin/rails g bug_reports_client:views
```

copies them into `app/views/bug_reports_client/` where they shadow the
engine's per file. The form posts a stable param contract, so you can also
hand-write a completely custom form - anything that submits these names works:

```
bug_report[title]
bug_report[report_type]                bug | feature
bug_report[severity]                   low | medium | high | critical (bugs)
bug_report[responses][<field_key>]     one per schema field
bug_report[screenshots][]              file uploads (optional)
```

Hosts can also override just the Turbo Stream dismissal hook
(`app/views/bug_reports_client/shared/_after_dismiss.turbo_stream.erb`) to
update their own UI - e.g. a notification badge - when an alert is dismissed.

## Styling

The engine views use plain Tailwind utilities; your app compiles the CSS, so
add the gem's views to your build:

**Tailwind v3** (`config/tailwind.config.js`):

```js
const { execSync } = require('child_process');
let bugReportsClient = '';
try { bugReportsClient = execSync('bundle show bug_reports_client').toString().trim(); } catch (e) {}

module.exports = {
  content: [
    './app/views/**/*.erb',
    // ...existing globs...
    bugReportsClient && `${bugReportsClient}/app/views/**/*.erb`,
    bugReportsClient && `${bugReportsClient}/app/helpers/**/*.rb`,
    bugReportsClient && `${bugReportsClient}/app/javascript/**/*.js`,
  ].filter(Boolean),
}
```

**Tailwind v4** (tailwindcss-rails >= 4.x): the engine ships
`app/assets/tailwind/bug_reports_client/engine.css`; add to
`app/assets/tailwind/application.css`:

```css
@import "../builds/tailwind/bug_reports_client";
```

## JavaScript

Three Stimulus controllers ship with the engine and are pinned into your
importmap automatically: `bug-reports-client--report-type` toggles the
bug/feature field groups, `bug-reports-client--screenshot-dropzone` powers
the drag-and-drop screenshot picker with thumbnail previews (the hidden file
input stays the submission source, so custom forms can ignore it; its
drag-over highlight is themeable via the `highlight-classes` Stimulus
value), and
`bug-reports-client--file-limit` is a standalone file-count guard for
hand-rolled forms. Any standard Stimulus setup that loads controllers from
the importmap (`eagerLoadControllersFrom` / `lazyLoadControllersFrom`) picks
them up with no changes.

## Automatic error capture (Sentry-style)

Opt in per host and unhandled 500s become GitHub issues, deduplicated:

```ruby
config.error_reporting_enabled = true
config.error_ignore = []          # extra exception class names to skip
config.error_throttle_period = 300 # seconds between posts per fingerprint
```

The engine subscribes to the Rails error reporter, so anything that would
render a 500 is captured; exceptions Rails maps to 4xx responses
(`RecordNotFound`, routing errors, etc) are skipped automatically. Errors
are fingerprinted by exception class + top application frame (line numbers
ignored, so deploys don't spawn duplicate issues), throttled through
`Rails.cache`, and posted in a background job so failing requests are never
slowed down. The API keeps one open issue per fingerprint, counting repeat
occurrences; when a closed error recurs, a fresh issue is filed (a
regression deserves new attention).

Captured errors are also attributed to the signed-in user who hit them
(stored locally in `bug_report_error_events`, pruned after 30 days). When
that user opens the report form within 24 hours, it asks "did this happen
alongside an error we caught?" - linking one threads the exception, time
and fingerprint into their report, so the GitHub issue cross-references the
automatically-filed error issue (search the repo for the fingerprint).
Existing installs: run `bin/rails bug_reports_client:install:migrations &&
bin/rails db:migrate` to pick up the events table.

## Webhook contract

The API POSTs closure callbacks to `<APP_HOST><mount_path>/webhook`, signed
with your app's webhook secret. Preferred scheme: `X-Timestamp` plus
`X-Signature-Timestamped: sha256=<hex>` where the HMAC-SHA256 covers
`"<timestamp>.<body>"` - the engine rejects timestamps older than 5 minutes
(replay protection). A legacy body-only `X-Signature` is also accepted when
no timestamp is sent. Bodies over 1 MB are rejected outright. The engine
verifies the signature, marks the local report closed, and returns 200. The
callback URL must be public HTTPS.

## Security notes

- **Screenshots are validated server-side**: content type is sniffed from
  the file bytes (not the client-declared type), and size/count limits apply
  (`screenshot_content_types`, `max_screenshot_size`, `max_screenshots`).
- **Screenshot URLs are embedded in GitHub issues** so maintainers can see
  them - which means uploads become unauthenticated public URLs on your
  storage service. If that's unacceptable, set `screenshots_enabled = false`
  or serve Active Storage through expiring/signed URLs.
- **Issue bodies contain verbatim user text.** Treat report content on the
  receiving side (GitHub, the central API) as untrusted: user answers can
  contain markdown, links and @mentions.
- **The issue template path is trusted config.** `issue_template_path` (and
  `config/bug_report_issue.md`) is read from disk verbatim - only ever point
  it at a file you control.

## Testing

The engine has its own test suite with a dummy host app:

```bash
cd client
bundle install
bundle exec rake test
```
