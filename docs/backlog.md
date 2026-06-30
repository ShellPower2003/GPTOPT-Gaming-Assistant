# Product backlog

Each epic requires acceptance criteria, tests, evidence sources, safety review, and documentation.

1. **Core app shell** — Windows host, navigation, dependency injection, configuration, and capability boundaries.
2. **Audit engine** — module discovery, isolation, schema validation, timeouts, and audit-only orchestration.
3. **Report engine** — JSON/CSV/TXT/HTML outputs, redaction, provenance, and deterministic rendering.
4. **CapFrameX/PresentMon analysis** — imports, capture metadata, comparable-session checks, and frametime evidence.
5. **Overlay conflict detection** — process/provider inventory, known-conflict rules, and source-linked explanations.
6. **NVIDIA/RTSS limiter validation** — effective-state inspection and limiter consistency checks without blind presets.
7. **Controller/input diagnostics** — device inventory, duplicate paths, polling evidence, and profile support.
8. **WPR/WPA trace workflow** — safe capture guidance, manifests, privacy warnings, and analysis handoff.
9. **Safe apply/undo system** — dry run, consent, backups, journals, idempotent undo, and recovery tests.
10. **Game profile marketplace-ready structure** — signed, versioned, declarative profiles with compatibility metadata.
11. **Installer/updater** — signed packages, atomic update, rollback, channel selection, and integrity verification.
12. **GUI polish** — PASS/WARN/ACTION presentation, accessibility, progress, errors, and report exploration.
13. **Privacy/security/trust** — threat model, opt-in telemetry boundary, redaction, signing, and dependency policy.
14. **Monetization readiness** — capability entitlements outside modules; no payment or licensing implementation yet.

## Immediate follow-up

Create one issue per epic after maintainers approve scope and labels. The first implementation milestone is a reference read-only module plus Pester tests proving discovery and schema conformance.
