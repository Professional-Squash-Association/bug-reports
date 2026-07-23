# Publishing bug_reports_client

The gem name `bug_reports_client` is unclaimed on rubygems.org (checked
21 Jul 2026) - the first `gem push` claims it.

## Recommended path

1. **Now -> v1.0**: PSA apps consume the engine via the Gemfile `github:`
   reference (private repo + read-only PAT). Iterate freely; tag releases as
   `client-vX.Y.Z` and pin hosts to tags once stable.
2. **v1.0**: publish to rubygems.org. This makes the client code public
   (even though this repo stays private) and lets PSA apps drop the Bundler
   PAT entirely - `gem "bug_reports_client", "~> 1.0"`.
3. **Open-sourcing the API (decided 22 Jul 2026)**: the whole bug-reports
   repo (API + this engine) is being prepared for public release - repo
   mapping now lives on ApiKey records (no PSA config in the tree), README/
   LICENSE/.env.example are written for a public audience, and the secret
   scan checklist below must pass before flipping the repo public.

### Before making the repository public

- [ ] Verify no secrets in the working tree OR the full git history
      (`git log -p` scan / gitleaks). If history contains secrets, publish
      from a fresh repository instead of flipping this one.
- [ ] Rotate every ApiKey token/webhook secret that ever appeared in a
      committed file (secure's key sits in its app's .env - rotate it).
- [x] fly.toml is gitignored/untracked (working copies stay local per
      deployment); a sanitised fly.toml.example ships instead. The old app
      name remains visible in git history - accepted as harmless.

## Release checklist

- [ ] Version bump in `lib/bug_reports_client/version.rb` (semver: breaking
      config/param-contract changes = major once past 1.0)
- [ ] CHANGELOG.md entry
- [ ] `bundle exec rake test` and `bundle exec rubocop` green (CI enforces
      both via .github/workflows/client-ci.yml)
- [ ] `gem build bug_reports_client.gemspec` - inspect the file list
      (`tar -tzf` the .gem) for anything unexpected; test/dummy must NOT ship
- [ ] Tag `client-vX.Y.Z` and push the tag
- [ ] `gem push bug_reports_client-X.Y.Z.gem`

## rubygems.org account setup (one-off)

- Create/use a PSA organisation-owned rubygems.org account with MFA enabled
  (the gemspec sets `rubygems_mfa_required`).
- Prefer a GitHub Actions release workflow using rubygems.org
  **trusted publishing** (OIDC - no long-lived API key) triggered on
  `client-v*` tags; until that exists, push manually from a maintainer
  machine.

## Things already in place

- MIT-LICENSE, README written for a non-PSA audience, CHANGELOG.
- `spec.files` ships only `app/config/db/lib` + docs (no tests, no dummy
  app, dotfiles filtered).
- No PSA-specific behaviour in engine code; all branding/wording is
  host-supplied via i18n and the form schema.
- Security review completed 21 Jul 2026 (screenshot uploads validated
  server-side, timestamped webhook signatures, scoped strong params).
