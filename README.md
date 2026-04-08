# Bug Reports

Centralised bug reporting API for PSA applications. Receives bug reports from any PSA app, creates GitHub issues on the correct repository, and notifies the source app when the issue is closed. Built with Ruby on Rails 8.1 as an API-only application.

## Prerequisites

- **Ruby**: 3.3.10 (see [.ruby-version](.ruby-version))
- **PostgreSQL**: 14+
- **Bundler**: Latest version

## Local Development Setup

### 1. Clone the repository

```bash
git clone https://github.com/Professional-Squash-Association/bug-reports.git
cd bug-reports
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Configure environment variables

Create a `.env` file in the project root with the required environment variables:

```bash
# GitHub API token for creating issues on repositories
GITHUB_ACCESS_TOKEN=your_github_token
```

### 4. Set up the database

```bash
bin/rails db:create db:migrate
```

### 5. Start the development server

```bash
bin/rails server -p 3002
```

## How It Works

1. A PSA app (e.g. Secure, Dashboard) sends a bug report to the API with a title, description, severity, and callback URL.
2. The API persists the report and resolves the correct GitHub repository using the source-to-repo mapping in [`config/repo_mapping.yml`](config/repo_mapping.yml).
3. A background job (`CreateGithubIssueJob`) creates a GitHub issue on the mapped repository via the Octokit gem.
4. When the GitHub issue is closed, a webhook event hits the API, marks the bug report as closed, and a second background job (`NotifySourceAppJob`) sends a signed callback to the source app.

## API Endpoints

All endpoints are namespaced under `/api` and require Bearer token authentication (except webhooks).

| Method | Path | Description |
| -------- | ------ | ------------- |
| `POST` | `/api/bug_reports` | Submit a new bug report |
| `GET` | `/api/bug_reports` | List all bug reports |
| `GET` | `/api/bug_reports/:id` | Show a single bug report |
| `POST` | `/api/webhooks` | Receive GitHub webhook events |

### Authentication

API requests are authenticated using Bearer tokens. Generate a key per app via the Rails console:

```ruby
ApiKey.create!(name: "secure")
```

Include the token in the `Authorization` header:

```bash
Authorization: Bearer <token>
```

### Example: Submit a bug report

```bash
curl -X POST http://localhost:3002/api/bug_reports \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "bug_report": {
      "title": "Login page returns 500",
      "description": "Clicking sign in on the login page throws an internal server error.",
      "severity": "high",
      "source": "secure",
      "reporter_email": "dev@example.com",
      "reporter_name": "Dev",
      "callback_url": "https://secure.example.com/api/bug_report_callbacks"
    }
  }'
```

Severity must be one of: `low`, `medium`, `high`, `critical`.

## Database Structure

The application uses PostgreSQL with multiple databases:

- `bug_reports_development` — Primary application database
- `bug_reports_development_queue` — Solid Queue background jobs

## Key Technologies

- **Rails 8.1** — API-only application framework
- **PostgreSQL** — Primary database
- **Solid Queue** — Background job processing (Solid Trifecta)
- **Solid Cache** — Database-backed caching
- **Solid Cable** — WebSocket connections
- **Octokit** — GitHub API client for issue creation

## Source-to-Repository Mapping

The file [`config/repo_mapping.yml`](config/repo_mapping.yml) maps each source app name to its GitHub repository. Update this file when adding a new PSA application.

## Development Tools

### Code Quality

```bash
bin/rubocop                   # Check code style (Rails Omakase)
bin/brakeman                  # Security vulnerability scan
```

### Background Jobs

Solid Queue processes jobs in-process via Puma in development, or as a separate process in production.

## Deployment

The application is deployed to [Fly.io](https://fly.io) using `flyctl` and the [fly.toml](fly.toml) configuration file.

```bash
# Deploy to production
flyctl deploy

# Open production console
flyctl ssh console --pty -C "/rails/bin/rails console"
```

## Support

For issues or questions, contact the PSA Digital Team.
