# Module contract

A GPTOPT module is an independently testable PowerShell module under `Modules/<ModuleName>/`. It owns one diagnostic domain and must not write outside its declared output or backup locations.

## Required commands

Every module exports:

- `Test-GPTOPTModulePrerequisite`: returns structured results describing availability and permissions.
- `Invoke-GPTOPTAudit`: performs read-only collection and returns result objects.
- `Invoke-GPTOPTAnalyze`: analyzes supplied evidence without changing the system.
- `Invoke-GPTOPTApply`: previews by default; with explicit approval, applies a declared reversible action.
- `Invoke-GPTOPTUndo`: restores state from an apply journal and verifies restoration.
- `Export-GPTOPTReport`: renders module-specific detail without changing canonical results.

## Discovery

The runner discovers `Modules/*/*.psd1`, imports each manifest, verifies the required commands, calls prerequisites, and calls only `Invoke-GPTOPTAudit`. A module must declare a unique manifest name and semantic version.

## Result contract

Every returned object must contain:

`Timestamp`, `Module`, `Category`, `Severity`, `Status`, `Finding`, `Evidence`, `RecommendedAction`, `Risk`, `UndoAvailable`, `Source`, and `Confidence`.

The canonical machine contract is `Config/schemas/gptopt-result.schema.json`. Modules return one result per independently actionable finding. Evidence contains observations, not marketing conclusions. `Source` identifies the command, file, event provider, tool, or documented rule that produced the claim.

## Apply and undo contract

Apply is never called by the audit runner. An apply request must include an action identifier, expected current state, dry-run support, risk, required privileges, backup plan, and verification method. Before mutation, the module writes an append-only journal containing original state and checksums where applicable. Undo consumes that journal, is idempotent, and reports verification evidence.

Security controls, Windows Update, and reboots are outside the permitted action surface.
