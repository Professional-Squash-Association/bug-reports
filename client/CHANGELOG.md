# Changelog

## 0.1.3 (7 October 2026)

- Unhandled errors raised by `bin/rails runner` scripts (Rails.error source
  `"application.runner.railties"`) are no longer reported. They have no
  application frame, so they all shared one fingerprint and merged into one
  misleading issue. Requests and jobs are still captured. The skipped sources
  are configurable via the new `config.ignored_error_sources` setting.

## 0.1.2 (16 August 2026)

- Resolved-report alerts no longer stack. When a user has two or more
  resolved, undismissed reports, the host layout shows a single collapsed
  banner listing every title with one "Dismiss all" button (new
  `PATCH /dismiss_all` route). A single resolved report keeps its own banner
  and per-report Dismiss as before. Hosts that copied `_alerts.html.erb` via
  the views generator will need to re-copy it to pick this up.

## 0.1.1 (24 July 2026)

- The screenshot dropzone's drag-over highlight classes are configurable via
  the `highlight-classes` Stimulus value, so dark-themed hosts can supply
  theme-appropriate classes instead of the light slate defaults.

- `BUG_REPORT_APP_HOST` takes precedence over the shared `APP_HOST` env var
  for the engine's public origin. `APP_HOST` is often owned by other host
  concerns (mailers, OIDC issuers) in formats the engine cannot assume -
  prefer the dedicated variable or an explicit `config.app_host`.

## 0.1.0 (23 July 2026)

- Initial release: mountable engine with a schema-driven report form
  (YAML-defined fields, report type cards, drag-and-drop screenshots with
  previews), my-reports and all-reports views, submission to the companion
  bug-reports API, signed closure webhooks (timestamped, replay-protected)
  and dismissable resolved-report alerts.
- Automatic error capture: unhandled 500s become deduplicated GitHub issues,
  attributed to the user who hit them so the report form can offer
  "did it relate to this error?".
- Install and views generators, i18n-based wording, optional markdown issue
  template with placeholder substitution.
