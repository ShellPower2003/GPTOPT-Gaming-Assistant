# Release plan

## Architecture preview

Deliver the module contract, result schema, read-only runner, product documents, and backlog. CI must parse PowerShell and JSON. No apply behavior ships.

## Developer preview

Ship signed first-party Windows, overlays, input, NVIDIA/RTSS, and capture-import modules. Add schema validation, Pester fixtures, deterministic reports, and malicious-module boundary tests.

## Public beta

Ship the Windows UI, installer/updater, report viewer, session comparison, backup/undo journal, crash recovery, accessibility review, privacy controls, and code signing. Apply remains opt-in and limited to reviewed actions.

## 1.0 readiness gates

- All findings validate against the published schema.
- Every action passes apply/undo/restoration tests on supported Windows versions.
- No critical security or data-loss issues remain.
- Claims have documented measurement protocols.
- Installer, updater, rollback, and disaster recovery are tested.
- Privacy disclosure matches observed network behavior.
- Support matrix and known limitations are published.

Releases use semantic versioning. Module API and result-schema compatibility are versioned independently. Unsupported modules fail closed and produce an explanatory result.
