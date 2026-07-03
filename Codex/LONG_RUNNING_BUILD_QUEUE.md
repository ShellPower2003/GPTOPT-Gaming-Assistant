# GPTOPT Long-Running Build Queue

Purpose: stop GPTOPT from depending on short daily chat fixes. This file is the sustained Codex work queue for multi-hour implementation sessions.

Branch: `feat/guided-control-center-slice`

Current PR: #24

Current known state:

- PR #24 is open.
- Guided Mode is the active product foundation.
- Guided card explanations have been added to the PR branch.
- Latest report review exists at `docs/LATEST_REPORT_REVIEW_20260702.md`.
- Next report-driven build handoff exists at `Codex/NEXT_BUILD_FROM_LATEST_REPORT.md`.
- PR is still not mergeable against `main` and must not be merged until fixed.

## Non-negotiable direction

GPTOPT is a product, not a pile of one-off scripts.

Halo Infinite is the first proving-ground profile, not the whole product.

The default user experience must answer:

> Am I ready to play, what matters, what is safe to change, and how do I undo it?

The default screen must not require the user to understand registry keys, raw process names, raw file paths, or PowerShell output.

## Work session rules for Codex

For each long work session:

1. Pull latest branch state.
2. Inspect changed files before editing.
3. Do not overwrite unrelated dirty files.
4. Make focused commits.
5. Run parser/smoke/safety checks before reporting done.
6. Push to the PR branch.
7. Report exact commits, files changed, validation run, and remaining blockers.

Do not claim done unless code is pushed.

## Safety rules

Do not add silent live system mutations in Guided Mode.

No automatic:

- registry writes
- Halo JSON writes
- RTSS profile writes
- service changes
- device disabling
- process kills
- scheduled task changes
- reboot/logoff/shutdown
- telemetry upload
- OpenAI API calls
- Vercel deployment

Any future apply action must show:

- what changes
- why it matters
- risk
- backup path
- undo path
- admin requirement
- reboot requirement

## Phase 0 - unblock PR #24

Goal: make PR #24 mergeable and safe.

Tasks:

1. Resolve merge conflict or mergeability blocker against `main`.
2. Confirm `gptopt.ps1` does not clobber the committed `Run-GPTOPT.ps1` router.
3. Confirm Guided Mode launches first from the one-line bootstrap path.
4. Confirm Advanced Control Center remains reachable.
5. Confirm `Knowledge/check-explanations.json` loads successfully.
6. Confirm every major Guided card has explanation coverage.
7. Confirm Show Details remains collapsed by default.
8. Confirm no guided-audit path writes registry, RTSS, Halo JSON, services, tasks, or processes.

Acceptance:

- PR reports mergeable or conflicts are clearly identified.
- Smoke test passes.
- Safety test passes.
- PowerShell parser checks pass.
- JSON parse checks pass.

## Phase 1 - report quality pass

Goal: make the GPTOPT report useful to a player.

Tasks:

1. Convert raw `Level=Info` outputs into player-facing readiness states:
   - Good
   - Review
   - Fix First
2. Apply selected profile rules for Halo baseline.
3. Make known-good values render as Good:
   - HAGS on for current profile
   - MPO disabled for current profile
   - Game Mode on
   - Game DVR off
   - VBS running services 0
4. Make cleanup-only pending reboot render as Review, not Fix First.
5. Show pre-launch vs in-session mode.
6. If Steam/Halo are not running, explicitly say only pre-launch readiness can be validated.

Acceptance:

- Latest report-style values produce mostly Good where expected.
- Report has a single top-level verdict.
- Report explains what is missing for in-session validation.

## Phase 2 - Halo-specific evidence

Goal: make Halo readiness real, not generic Windows checking.

Tasks:

1. Add Halo JSON summary:
   - resolution
   - window mode
   - render scale
   - VSync
   - HDR/WCG
   - min frame rate
   - target frame rate
   - competitive visual toggles summary
2. Add RTSS Halo profile summary:
   - profile path exists
   - FramerateLimit equals 240
   - ApplicationDetectionLevel equals 2
   - OSD enabled when expected
   - stealth/custom D3D not causing capture issues
3. Add Steam/Halo process state summary.
4. Add capture tooling summary:
   - CapFrameX installed/running
   - PresentMon installed/running
   - RTSS running
   - MSI Afterburner running

Acceptance:

- Halo report can distinguish missing app state from bad config.
- RTSS baseline is strict enough for the user's 240 FPS cap workflow.

## Phase 3 - controller/audio layer

Goal: account for the user's actual feel stack.

Tasks:

1. Add Flydigi controller stack summary:
   - SpaceStation process
   - GameControllerService
   - controller device presence where available
   - do not recommend killing Flydigi as bloat
2. Add Sonar audio summary:
   - SteelSeries/Sonar process
   - Sonar device/service fallback where available
   - do not recommend killing Sonar as bloat
3. Add explanation cards for input and audio routing.
4. Add warnings when virtual mouse/keyboard behavior may interfere, but do not disable automatically.

Acceptance:

- Controller and audio are first-class readiness areas.
- User-specific keep-running tools are respected.

## Phase 4 - cloud-safe report export

Goal: prepare for Vercel/OpenAI without leaking private local data.

Tasks:

1. Add schema:
   - `Schemas/gptopt-cloud-report.schema.json`
2. Add exporter:
   - sanitized JSON output under `Reports/`
3. Redact/omit:
   - Windows username
   - full local paths
   - raw repo file inventory
   - environment variables
   - tokens/API keys/secrets
   - unrelated personal files
4. Preserve useful summaries:
   - hardware class
   - display summary
   - selected profile
   - readiness verdict
   - findings
   - risk labels
   - explanation IDs
   - recommended actions

Acceptance:

- Full local report remains available locally.
- Cloud-safe report contains no obvious private path or username patterns.
- Tests validate sanitizer behavior.

## Phase 5 - Vercel dashboard scaffold

Goal: create a web product path without requiring cloud credentials yet.

Tasks:

1. Add `web/` scaffold.
2. Use static/mock GPTOPT cloud-safe report data.
3. Show dashboard sections:
   - readiness verdict
   - findings
   - recommended actions
   - explanations
   - session mode
   - game profile
4. Add `web/README.md` with local dev instructions.
5. Do not require `OPENAI_API_KEY` in this phase.
6. Do not upload real PC data.

Acceptance:

- Web scaffold has documented install/build path.
- Dashboard can render mock report data.
- Local GPTOPT remains independent/offline.

## Phase 6 - OpenAI research layer design

Goal: prepare the AI layer without hardwiring unsafe behavior.

Tasks:

1. Add architecture doc for future OpenAI integration.
2. Define allowed AI actions:
   - explain report
   - compare reports
   - summarize changes
   - suggest safe next tests
   - research source-backed game/profile updates
3. Define forbidden AI actions:
   - direct Windows writes
   - automatic apply
   - secret collection
   - unsanitized report upload by default
4. Add eval ideas for hallucination and safety:
   - must cite source-backed claims
   - must not invent local state
   - must not recommend disabling required Flydigi/Sonar tools

Acceptance:

- OpenAI path is documented.
- No API key is required yet.
- No runtime cloud call is added yet.

## Phase 7 - GitHub Actions gates

Goal: prevent regressions.

Tasks:

1. Validate JSON files parse.
2. Validate schemas parse.
3. Validate explanation coverage.
4. Validate PowerShell parser syntax.
5. Validate no obvious secret patterns committed.
6. Validate cloud-safe sample does not contain username/full local path patterns.

Acceptance:

- CI fails if explanation catalog or report schema breaks.
- CI fails on parser errors.

## Definition of done for this long build queue

A long Codex work session is done only when:

- commits are pushed
- PR status is reported
- tests run are listed
- failures are listed honestly
- next blocker is specific

Do not stop at docs only if code changes are required. Docs are useful only when paired with implementation or exact acceptance gates.
