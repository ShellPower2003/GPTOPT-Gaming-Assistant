# GPTOPT Gaming Assistant architecture

GPTOPT is a consumer-facing, game-agnostic Windows application built around evidence-producing modules and a reversible action boundary.

## Target structure

```text
App/
  GPTOPT.UI/        GPTOPT.Core/       GPTOPT.Modules/
  GPTOPT.Reports/   GPTOPT.Updater/
Scripts/
  Audit/ Analyze/ Apply/ Capture/ Diagnostics/ Undo/
Modules/
  GPTOPT.Core/ CapFrameX/ PresentMon/ Nvidia/ RTSS/
  Windows/ Input/ Overlays/ WPR/
Profiles/
  Games/ Hardware/ Displays/ Controllers/
Config/
  appsettings.json rules.json known-conflicts.json supported-tools.json schemas/
docs/
tests/
  Pester/ Fixtures/ SampleCaptures/
```

Directories are introduced when they contain an owned artifact; empty scaffolding is not required.

## Runtime flow

`UI or CLI -> Core runner -> module contract -> canonical results -> report engine`

The core runner discovers manifests, validates module capabilities, executes read-only audits, validates results, and passes immutable result records to reports. The UI renders results and requests actions but contains no system-tuning logic.

## Components

- **GPTOPT.Core:** discovery, orchestration, policy, schema validation, timeouts, and action authorization.
- **GPTOPT.Modules:** first-party module packaging and shared module SDK.
- **Domain modules:** Windows, overlays, input, NVIDIA/RTSS, capture tools, and WPR guidance.
- **GPTOPT.Reports:** deterministic JSON, CSV, text, and HTML rendering with redaction.
- **GPTOPT.UI:** PASS/WARN/ACTION workflows, evidence inspection, consent, and undo.
- **GPTOPT.Updater:** signed, atomic updates with rollback.
- **Profiles:** declarative compatibility and game-specific rules; Halo is one profile.
- **Apply/Undo:** a separately authorized transactional layer with backups and journals.

## Dependency rules

Modules depend on the published contract, not the UI. Reports consume canonical results and never recollect evidence. Profiles contain data, not arbitrary executable code. Entitlement checks belong at the application capability boundary, never inside findings or evidence collection.

## Security and failure model

Audit is the default and cannot call apply. Unsupported, unavailable, timed-out, or invalid modules fail closed and emit structured results. Mutations require explicit consent and a verified recovery path. Module provenance, signing, least privilege, report redaction, and action journals are release gates.

The authoritative contracts are `docs/module-contract.md`, `docs/safety-policy.md`, and `Config/schemas/gptopt-result.schema.json`.
