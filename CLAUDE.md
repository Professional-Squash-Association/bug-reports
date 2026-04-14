# Bug Reports

Centralized bug report tracking service for PSA applications. API-only Rails app.

## Architecture

### Flow

1. PSA app submits bug report via `POST /api/bug_reports` (Bearer token auth)
2. `CreateGithubIssueJob` creates a GitHub issue via Octokit
3. When a developer closes the issue on GitHub, a webhook hits `POST /api/webhooks`
4. `NotifySourceAppJob` POSTs back to the source app's `callback_url` with an HMAC-signed payload

### Key Models

- **BugReport** — core domain model. Tracks title, description, severity (`low/medium/high/critical`), status (`pending/closed`), source app, reporter info, callback URL, and linked GitHub issue details.
- **ApiKey** — Bearer token + webhook_secret per source app. Secrets auto-generated on create.
- **RepoMapping** — YAML-based lookup (`config/repo_mapping.yml`) mapping source app names to GitHub repos. Currently only `secure` is mapped.

### Jobs

All jobs use Solid Queue, retry up to 5 times with polynomial backoff.

- **CreateGithubIssueJob** — creates GitHub issue, stores issue number/URL on BugReport
- **UpdateGithubIssueJob** — syncs title/description/labels to GitHub when a BugReport is updated
- **NotifySourceAppJob** — HMAC-signs payload with ApiKey's `webhook_secret`, POSTs to `callback_url`. Validates callback is HTTPS with a public IP.

### API Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/bug_reports` | Bearer token | Create bug report |
| GET | `/api/bug_reports` | Bearer token | List all bug reports |
| GET | `/api/bug_reports/:id` | Bearer token | Show bug report |
| PATCH | `/api/bug_reports/:id` | Bearer token | Update bug report |
| POST | `/api/webhooks` | GitHub HMAC signature | Receive GitHub webhook |

### Authentication

- **API endpoints** use Bearer token auth via `ApiKey.token` (checked in `ApplicationController`)
- **Webhook endpoint** verifies `X-Hub-Signature-256` header against `GITHUB_WEBHOOK_SECRET` env var

## Stack

- Rails 8.1 (API-only), Ruby 3.3.10
- PostgreSQL
- Solid Trifecta (SolidQueue, SolidCache, SolidCable)
- Octokit for GitHub API
- Port: 3002

## Environment Variables

- `GITHUB_TOKEN` — GitHub PAT for Octokit (issue creation/updates)
- `GITHUB_WEBHOOK_SECRET` — shared secret for verifying inbound GitHub webhooks

## Testing

- Minitest with fixtures
- `bin/rails test` to run, `COVERAGE=1 bin/rails test` for SimpleCov coverage
- Jobs mock the GitHub client using singleton methods
- Controller tests use `ActionDispatch::IntegrationTest`
