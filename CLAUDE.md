# Bug Reports

Self-hostable bug report tracking service. API-only Rails app; the
`bug_reports_client` Rails engine gem lives in `client/` in this same repo.

## Architecture

### Flow

1. A consuming app submits a report via `POST /api/bug_reports` (Bearer token auth)
2. `CreateGithubIssueJob` creates a GitHub issue via Octokit (dry-run in development)
3. When a developer closes the issue on GitHub, a webhook hits `POST /api/webhooks`
4. `NotifySourceAppJob` POSTs back to the source app's `callback_url` with HMAC-signed payloads (timestamped + legacy signatures)

### Key Models

- **BugReport** — core domain model. Tracks title, description, severity (`low/medium/high/critical`), status (`pending/closed`), report type (`bug/feature`), source app, reporter info, callback URL, and linked GitHub issue details.
- **ApiKey** — one record per consuming app: Bearer `token`, `webhook_secret` for callback signing, and `github_repo` (owner/repository) where that app's issues are filed. Secrets auto-generated on create. Onboard apps with `ApiKey.create!(name:, github_repo:)`.

### Jobs

All jobs use Solid Queue, retry up to 5 times with polynomial backoff.

- **CreateGithubIssueJob** — creates the GitHub issue, stores issue number/URL on BugReport. Respects `GithubDryRun`.
- **UpdateGithubIssueJob** — syncs title/body/labels to GitHub when a BugReport is updated. Respects `GithubDryRun`.
- **NotifySourceAppJob** — signs the closure payload with the app's `webhook_secret` (timestamped and legacy signatures), POSTs to `callback_url`. Validates the callback is HTTPS resolving to a public IP.

### Services

- **GithubApp** — Octokit client authenticating as a GitHub App installation, falling back to `GITHUB_TOKEN`.
- **GithubIssuePayload** — builds the exact issue payload (repo/title/body/labels); shared by jobs, dry-run and the preview task.
- **GithubDryRun** — active in development or `GITHUB_DRY_RUN=true`; logs payloads instead of calling GitHub. `bin/rails bug_reports:preview` prints payloads for stored reports.

### API Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/bug_reports` | Bearer token | Create bug report |
| GET | `/api/bug_reports` | Bearer token | List all bug reports |
| GET | `/api/bug_reports/:id` | Bearer token | Show bug report |
| PATCH | `/api/bug_reports/:id` | Bearer token | Update bug report |
| POST | `/api/webhooks` | GitHub HMAC signature | Receive GitHub webhook |

Ownership: an app's token only permits reports whose `source` equals its ApiKey name (403 otherwise).

## Stack

- Rails 8.1 (API-only), Ruby 3.3.10
- PostgreSQL, Solid Trifecta (SolidQueue, SolidCache, SolidCable)
- Octokit for GitHub API
- Port: 3002

## Environment Variables

See `.env.example`. `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PRIVATE_KEY` (issues created as a bot), `GITHUB_TOKEN` (fallback PAT), `GITHUB_WEBHOOK_SECRET` (inbound webhook verification), `GITHUB_DRY_RUN` (force dry-run outside development).

## Testing

- Minitest with fixtures; `bin/rails test` (`COVERAGE=1` for SimpleCov)
- Jobs mock the GitHub client using singleton methods
- The engine has its own suite: `cd client && bundle exec rake test`
