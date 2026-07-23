# Contributing

Thanks for your interest! This repository contains two pieces:

- the **API** (repository root) - Rails 8.1 API-only app
- the **client engine** (`client/`) - the `bug_reports_client` gem

## Getting started

```bash
bundle install && bin/rails db:prepare && bin/rails test   # API
cd client && bundle install && bundle exec rake test        # engine
```

Both are linted with RuboCop (Rails Omakase): `bin/rubocop` at the root,
`bundle exec rubocop` in `client/`. The API is also scanned with
`bin/brakeman`. CI runs all of these on pull requests.

## Guidelines

- Add or update tests for any behaviour change (the engine's suite runs
  against the dummy host app in `client/test/dummy`).
- Wording changes belong in i18n (`client/config/locales/en.yml`), not views.
- Keep the engine free of app-specific behaviour - anything host-specific
  should be configurable via `BugReportsClient.configure`, the form schema,
  or locale overrides.
- Development never contacts GitHub (dry-run mode) - use
  `bin/rails bug_reports:preview` to inspect would-be issue payloads.
