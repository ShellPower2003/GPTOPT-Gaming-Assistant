# Safety policy

GPTOPT is diagnostic software, not tweakware.

## Non-negotiable rules

- Default operation is read-only audit.
- Never disable or weaken Defender, firewall, TPM, Secure Boot, Memory Integrity, or Windows Update.
- Never delete or overwrite configuration without a verified backup.
- Never change service startup state without recording the original state and providing tested undo.
- Never reboot automatically.
- Never collect hidden telemetry.
- Never claim an FPS, latency, or frametime improvement without comparable measurement evidence.
- Prefer temporary, session-scoped behavior over permanent system-wide changes.
- Always show risk, scope, prerequisites, expected effect, verification, and undo path before apply.

## Action lifecycle

`Discover -> Preview -> Consent -> Backup -> Apply -> Verify -> Journal -> Undo -> Verify restoration`

Failure at any stage stops subsequent mutation. Partial changes must be represented in the journal and surfaced as a high-severity result.

## Trust boundaries

Modules run with the least privilege needed. Elevation is requested only for a named action. The UI cannot directly mutate the system; it calls the action layer. Downloaded modules and profiles require provenance and integrity verification before execution.

## Claims and evidence

A claim must identify its source, collection time, confidence, and evidence. Recommendations must distinguish correlation from causation. Before/after comparisons must use comparable settings, scenes, capture duration, warm-up, and tool versions.

## Privacy

Local processing is the default. Reports may contain hardware, process, path, and game-session information and must be previewed before export. Telemetry is off unless the user gives informed opt-in consent; telemetry implementation is out of scope for the architecture PR.
