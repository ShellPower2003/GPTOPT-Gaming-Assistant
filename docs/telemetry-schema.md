# Telemetry and local event schema

No telemetry is implemented by this change. GPTOPT processes locally by default, and future telemetry must be explicit opt-in, documented, revocable, and separable from diagnostics.

## Local event envelope

Operational events should use:

- `eventId`: random identifier
- `eventName`: stable namespaced name
- `schemaVersion`: event schema version
- `timestamp`: UTC ISO 8601
- `appVersion`, `module`, `moduleVersion`
- `sessionId`: locally generated, rotated identifier
- `properties`: allow-listed values
- `consentState`: `local-only` or `opted-in`

Diagnostic findings use the canonical result schema and are not telemetry.

## Prohibited data

Never collect credentials, tokens, full file contents, input contents, browsing history, chat content, precise location, or stable device fingerprints. Raw process paths, usernames, IP addresses, serial numbers, and report evidence are excluded from telemetry.

## Governance

Any future transport requires a public data dictionary, retention limit, deletion mechanism, consent UI, endpoint allow-list, failure-safe local operation, and tests proving that opt-out sends nothing. Schema changes require versioning and privacy review.
