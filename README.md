# Bug Reports

A small, self-hostable bug-reporting service for teams running multiple
apps. Your applications submit bug reports and feature requests to this API;
it files them as GitHub issues on the right repository, and calls the source
app back with a signed webhook when the issue is closed - so reporters can be
told "your report has been resolved".

Built with Ruby on Rails 8.1 as an API-only application. Pairs with
[`bug_reports_client`](client/) - a mountable Rails engine that gives any
Rails app a polished, schema-driven report form, screenshot uploads, a
my-reports page and resolved-report alerts with a few lines of setup.

```
Your app (bug_reports_client gem)          This API                 GitHub
  submit form ── POST /api/bug_reports ──▶ persist + resolve repo
                                           CreateGithubIssueJob ──▶ issue created
                                                                    issue closed
                                           POST /api/webhooks ◀──── webhook
  signed callback ◀── NotifySourceAppJob ─ mark closed
  "your report was resolved" banner
```

## Requirements

- Ruby 3.3+ (see [.ruby-version](.ruby-version)), PostgreSQL 14+
- A GitHub App (recommended) or a personal access token that can create
  issues on your repositories

## Setup

```bash
bundle install
cp .env.example .env       # then fill in the GitHub credentials
bin/rails db:prepare       # creates the database and a demo API key in dev
bin/rails server -p 3002
```

### GitHub credentials

Two options, configured via environment variables (see
[.env.example](.env.example)):

1. **GitHub App (recommended)** - issues are created by a bot identity, not
   a personal account. Create an app under your organisation
   (Settings -> Developer settings -> GitHub Apps) with **Issues:
   read & write** repository permission and the **Issues** webhook event,
   install it on every repository that should receive issues, then set
   `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` and
   `GITHUB_APP_PRIVATE_KEY` (the PEM contents).
2. **Personal access token** - set `GITHUB_TOKEN` (fine-grained, Issues
   read/write on the target repos). Used automatically when no app is
   configured.

Point the GitHub (App or repository) webhook at
`https://<your-host>/api/webhooks` for **Issues** events, and set the same
secret in `GITHUB_WEBHOOK_SECRET` - inbound webhooks are verified against
`X-Hub-Signature-256`.

### Onboarding an application

Each consuming app is one `ApiKey` record - no config files, no deploys:

```ruby
ApiKey.create!(name: "myapp", github_repo: "my-org/myapp")
```

The record carries everything the app needs: `token` (Bearer auth),
`webhook_secret` (verifying closure callbacks) and the GitHub repository its
reports are filed on. An app may only create/update reports whose `source`
matches its own key name.

If the app is Rails, install the [`bug_reports_client`](client/README.md)
gem and set `BUG_REPORT_API_URL`, `BUG_REPORT_API_KEY`,
`BUG_REPORT_WEBHOOK_SECRET` and `APP_HOST` - everything else is provided.

## API

All endpoints are under `/api`. Bearer token auth everywhere except the
GitHub webhook receiver.

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/bug_reports` | Bearer token | Create a report (returns 202 + id) |
| GET | `/api/bug_reports` | Bearer token | List reports |
| GET | `/api/bug_reports/:id` | Bearer token | Show a report |
| PATCH | `/api/bug_reports/:id` | Bearer token | Update a report (re-syncs the issue) |
| POST | `/api/error_reports` | Bearer token | Automatic 500 capture, deduplicated by fingerprint |
| POST | `/api/webhooks` | GitHub HMAC | Receive GitHub issue events |

Error reports (`report_type: "error"`) are machine-generated 500 captures
from the client engine: no reporter details or callback URL, deduplicated by
`source` + `fingerprint` - repeats of an open error bump its
`occurrence_count` rather than filing duplicate issues, and a recurrence
after the issue is closed files a fresh one.

```bash
curl -X POST http://localhost:3002/api/bug_reports \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "bug_report": {
      "title": "Login page returns 500",
      "description": "Markdown body for the GitHub issue.",
      "severity": "high",
      "report_type": "bug",
      "source": "myapp",
      "reporter_email": "someone@example.com",
      "reporter_name": "Someone",
      "callback_url": "https://myapp.example.com/bug_reports/webhook"
    }
  }'
```

`severity`: `low|medium|high|critical` (required for bugs). `report_type`:
`bug|feature`. `callback_url` must be public HTTPS - it is validated at
submission time and again (with DNS resolution, blocking private/loopback
addresses) before every callback.

### Closure callbacks

When an issue is closed on GitHub, the source app's `callback_url` receives
a JSON POST signed with that app's `webhook_secret`:

- `X-Timestamp` - unix seconds, and
- `X-Signature-Timestamped: sha256=<hex>` - HMAC-SHA256 over
  `"<timestamp>.<body>"` (receivers should reject stale timestamps), plus
- `X-Signature: sha256=<hex>` - legacy HMAC over the body alone, kept for
  older receivers.

The `bug_reports_client` engine implements the receiving side, including
replay protection.

## Development

- **GitHub dry-run**: in development (or with `GITHUB_DRY_RUN=true`), issue
  creation/updates are logged instead of sent - nothing touches GitHub.
  Inspect the exact would-be payload for stored reports with
  `bin/rails bug_reports:preview` (`LIMIT=25` or `ID=3`).
- **Local webhooks**: `gh extension install cli/gh-webhook`, then
  `gh webhook forward --repo=<org>/<repo> --events=issues
  --secret=$GITHUB_WEBHOOK_SECRET --url=http://localhost:3002/api/webhooks`.
- **Tests**: `bin/rails test` (`COVERAGE=1` for SimpleCov). The client
  engine has its own suite: `cd client && bundle exec rake test`.
- **Linting/scanning**: `bin/rubocop`, `bin/brakeman`.

## Stack

Rails 8.1 API-only, PostgreSQL, Solid Queue/Cache/Cable, Octokit. Background
jobs retry 5 times with polynomial backoff. This repository also contains
the [`bug_reports_client`](client/) engine gem under `client/`.

## Deployment

Any Rails-friendly host works. For [Fly.io](https://fly.io), copy
[fly.toml.example](fly.toml.example) to `fly.toml` (gitignored - deployment
config is per-installation), set your app name, add the environment
variables as secrets, and `fly deploy`.

## Licence

MIT - see [LICENSE](LICENSE).
