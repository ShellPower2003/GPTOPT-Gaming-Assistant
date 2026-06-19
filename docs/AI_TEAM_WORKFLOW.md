# GPTOPT AI Team Workflow

GPTOPT should be built with multiple AI roles, not as one-off chat scripts. ChatGPT and Codex should work together like a small product team.

## Core principle

Codex is part of the build team. It is not just a prompt target and not just a place to paste scripts. Codex should help implement, refactor, test, and prepare changes against the repo.

ChatGPT should drive product direction, research, architecture, safety rules, and review. Codex should help turn that into working code.

## Roles

### ChatGPT role

ChatGPT owns:

- product direction
- user experience direction
- competitive gaming research synthesis
- safety policy for system-changing actions
- knowledge model design
- repo roadmap
- review of logs and player feedback
- deciding what should be built next
- translating raw technical results into product requirements

ChatGPT should not stop at answering the latest symptom. It should continuously improve GPTOPT as a product.

### Codex role

Codex owns:

- implementing repo changes
- refactoring scripts into maintainable modules
- creating or improving GUI code
- adding tests and validation scripts
- reducing duplicated logic
- making launcher/update flow reliable
- preparing PR-sized changes
- fixing bugs found by local runs
- converting product requirements into concrete code

Codex should inspect the repo before editing and should not blindly generate isolated scripts.

### User role

The user should only be needed for things that require the local Windows machine:

- running the one-line launcher
- testing the GUI visually
- confirming controller/audio/game feel
- approving risky live system changes
- providing logs when local execution fails

The user should not have to repeatedly decide file structure, explain obvious next features, or interpret raw registry/process output.

## Build loop

1. Research and learn.
2. Inspect current repo state.
3. Decide the next product improvement.
4. Use Codex or direct repo edits to implement the change.
5. Add validation or tests where possible.
6. Push or prepare a patch.
7. User runs one local command only when Windows execution is required.
8. Feed results back into the knowledge model.

## What not to do

- Do not create issue spam before trying to build.
- Do not rely on the user to define every next step.
- Do not keep producing giant pasted scripts when the repo can own the behavior.
- Do not hardcode Halo as the whole product.
- Do not hide risky changes behind vague buttons.
- Do not copy random tweak guides without verification and rollback.

## Codex usage rule

Use Codex when the task is code-heavy, refactor-heavy, test-heavy, or requires broad repo editing. Codex should receive context as a teammate:

- product goal
- current repo state
- files to inspect
- safety constraints
- expected behavior
- acceptance checks

Do not ask Codex to "just improve everything." Ask it to build a specific product slice.

## Example teammate handoff

Build a guided control center product slice.

Context:

- GPTOPT is a competitive PC gaming optimization platform.
- Halo Infinite is the first reference profile, not the whole product.
- The user needs plain-language readiness cards instead of raw technical output.
- The one-line launcher should open Guided Mode first.

Inspect:

- `gptopt.ps1`
- `Run-GPTOPT.ps1`
- `Scripts/Invoke-GPTOPTGuidedControlCenter.ps1`
- `Scripts/Invoke-GPTOPTControlCenter.ps1`
- `Knowledge/gptopt-health-model.json`
- `Knowledge/game-profile-schema.json`
- `docs/GUIDED_CONTROL_CENTER_ARCHITECTURE.md`

Build:

- profile selector
- readiness verdict
- guided health cards
- advanced detail expansion
- action queue with risk/backup/undo text
- report export

Acceptance:

- no destructive action on launch
- no destructive action during audit
- Guided Mode opens from the one-line launcher
- Advanced mode remains reachable
- missing apps/files do not crash the UI

## Long-term direction

GPTOPT should become a real Windows program. PowerShell can remain the bootstrap and advanced automation layer, but the product should evolve toward a proper app with:

- guided UX
- game profiles
- player routines
- pro-study learning loop
- telemetry/reports
- safe rollback
- updater
- tests

Codex should help implement this transition incrementally without breaking the working scripts.