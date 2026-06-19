# GPTOPT Codex Operating Guide

GPTOPT must use Codex as a builder, not as a vague chat helper. Codex work should be file-focused, testable, and tied to the product direction: guided competitive PC gaming optimization.

## Product direction

GPTOPT is a competitive PC gaming optimization platform. Halo Infinite is the first proving-ground profile, not the whole product.

The default experience should be guided and non-technical. Advanced details should exist, but they should not be the first thing a normal user sees.

## How to task Codex

Every Codex task should include:

1. Goal
2. Files to inspect first
3. Files to modify
4. Files not to touch
5. Safety constraints
6. Acceptance checks
7. Manual Windows checks, if required

Do not ask Codex to broadly improve the repo without boundaries. Use focused tasks that produce a working patch.

## Required safety rules

Codex must not silently add risky Windows mutations. Any action that changes registry, services, device state, Halo JSON, RTSS profiles, scheduled tasks, startup items, or power settings must declare:

- what changes
- why it changes
- risk level
- backup path
- undo path
- admin requirement
- reboot requirement

For GUI work, prefer read-only interpretation first. Put write actions behind explicit buttons and confirmation text.

## Default build order

1. Read the current launcher path: `gptopt.ps1`, `Run-GPTOPT.ps1`, and GUI entry scripts.
2. Read knowledge files in `Knowledge/`.
3. Improve guided UI cards and action queue.
4. Add or refine game profiles.
5. Add tests or validation scripts.
6. Update docs only after behavior changes.

## Codex prompt templates

### Guided UI improvement

Goal: Improve GPTOPT Guided Control Center so a non-technical user can understand readiness without reading registry/process names.

Inspect first:

- `gptopt.ps1`
- `Run-GPTOPT.ps1`
- `Scripts/Invoke-GPTOPTGuidedControlCenter.ps1`
- `Scripts/Invoke-GPTOPTControlCenter.ps1`
- `Knowledge/gptopt-health-model.json`
- `Knowledge/game-profile-schema.json`
- `docs/GUIDED_CONTROL_CENTER_ARCHITECTURE.md`

Modify:

- `Scripts/Invoke-GPTOPTGuidedControlCenter.ps1`
- knowledge files if card wording or rules need expansion

Do not modify:

- Halo JSON directly
- RTSS profile directly
- registry write scripts unless explicitly asked

Acceptance checks:

- Guided Mode opens from `Run-GPTOPT.ps1`.
- First screen shows a plain-language verdict: Ready to Play, Ready with Review, or Fix First.
- Every card has status, meaning, recommended action, risk, and technical detail hidden by default.
- Advanced mode is still reachable.

### Game profile work

Goal: Add or improve a game profile without making unsafe system changes.

Inspect first:

- `Knowledge/game-profile-schema.json`
- `Knowledge/gptopt-health-model.json`
- existing profile files under `Profiles/` if present

Modify:

- profile knowledge/config files only

Acceptance checks:

- Profile defines executable names, launcher, display policy, limiter policy, input policy, audio policy, overlay policy, warmup routine, review questions, and safety rules.
- Profile does not include unverified destructive tweaks.

### Audit interpreter work

Goal: Convert raw GPTOPT audit output into beginner-friendly cards.

Inspect first:

- latest audit/report generation scripts
- `Knowledge/gptopt-health-model.json`
- `docs/GUIDED_CONTROL_CENTER_ARCHITECTURE.md`

Acceptance checks:

- Raw values are preserved for advanced view.
- Beginner view shows what matters and what to do.
- Firefox/browser noise can be filtered from gaming readiness unless the selected profile is browser-based.

## What Codex should not do by default

- Do not create issue spam.
- Do not rewrite the whole repo without a migration path.
- Do not replace working scripts with untested abstractions.
- Do not copy random internet tweak lists into GPTOPT.
- Do not hardcode one user’s machine as the only supported target.
- Do not remove Halo-specific work; convert it into the first game profile.

## Manual Windows work boundary

Codex and ChatGPT cannot run Windows PowerShell on the user's PC unless the user runs the produced command locally. When a task requires live registry, process, device, RTSS, Halo, or controller testing, Codex should produce a one-command local validation path and a clear expected result.
