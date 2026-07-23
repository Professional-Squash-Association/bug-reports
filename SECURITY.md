# Security Policy

## Reporting a vulnerability

Please do not open public issues for security problems. Email
digital@psasquashtour.com with the details and we will respond as quickly as
we can. Include reproduction steps where possible.

## Scope notes for self-hosters

- API authentication is per-app Bearer tokens (`ApiKey` records); closure
  callbacks are HMAC-SHA256 signed (timestamped + legacy schemes).
- Callback URLs must be public HTTPS; DNS is resolved and private/loopback/
  link-local addresses are rejected before every callback (SSRF hardening).
- Inbound GitHub webhooks are verified against `X-Hub-Signature-256`.
- Issue bodies contain verbatim reporter text - treat them as untrusted
  content on the GitHub side.
