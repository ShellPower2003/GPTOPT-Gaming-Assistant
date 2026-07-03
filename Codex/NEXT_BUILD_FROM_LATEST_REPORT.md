# Codex Next Build - Latest Report Follow-up

Branch target: `feat/guided-control-center-slice`

Source context: user ran GPTOPT Guided Test and provided `GPTOPT-Report_20260702_234819.json` output.

## Goal

Turn the latest report into a better product. Do not add more raw script output. Improve Guided Mode so it gives a player-ready answer and creates a sanitized report that can later feed Vercel/OpenAI.

## Files to inspect first

- `Run-GPTOPT.ps1`
- `Scripts/Invoke-GPTOPTGuidedControlCenter.ps1`
- `Scripts/Test-GPTOPTSafety.ps1`
- `Scripts/Write-GPTOPTReportBundle.ps1`
- `Scripts/Get-GPTOPTRecommendation.ps1`
- `Knowledge/check-explanations.json`
- `Knowledge/gptopt-health-model.json`
- `Knowledge/game-profile-schema.json`
- `docs/LATEST_REPORT_REVIEW_20260702.md`
- `docs/GUIDED_CHECK_EXPLANATIONS.md`

## Required implementation

### 1. Convert info checks to readiness states

The latest report marks most findings as `Level=Info`. Guided Mode should compute user-facing readiness:

- `Good`
- `Review`
- `Fix First`

Use selected game profile rules. For Halo baseline:

- HAGS `HwSchMode=2` = Good
- MPO `OverlayTestMode=5` = Good
- Game Mode enabled = Good
- Game DVR disabled = Good
- VBS running services 0 = Good/Info
- PendingFileRenameOperations-only cleanup = Review, not Fix First
- Windows Update/CBS reboot = Fix First or Action

### 2. Add cloud-safe report export

Create a sanitized report path separate from the full local report.

Suggested output:

- `Reports/GPTOPT-CloudSafeReport_<timestamp>.json`

Cloud-safe report must not include:

- Windows username
- full local paths
- full repo file inventory
- raw environment variables
- tokens/secrets/API keys
- unrelated personal files

Cloud-safe report should include:

- generated timestamp
- selected profile
- anonymized hardware class summary
- display summary
- readiness verdict
- findings
- recommended actions
- risk labels
- explanation IDs
- evidence summaries, not raw paths

### 3. Split full local report from default player report

The full local report may keep developer evidence, but Guided Mode should default to a player-readable report.

Hide or move to Advanced Details:

- full repo file inventory
- raw file paths
- low-level evidence dumps

### 4. Add Halo session specificity

The report showed Steam and Halo were not running. GPTOPT should distinguish:

- Pre-launch readiness
- In-session readiness
- Post-capture analysis

If Halo is not running, the UI should say it can only validate pre-launch readiness.

### 5. Add missing summaries

Add high-level report sections for:

- Halo JSON baseline summary
- RTSS Halo profile summary
- Flydigi controller stack summary
- SteelSeries Sonar summary
- capture tooling summary
- background load summary with Firefox ignore support

### 6. Wire explanations into Guided Mode

Load `Knowledge/check-explanations.json` and attach explanation data to every major card:

- label
- summary
- why it matters
- good state
- safe action
- risk
- undo path

Raw evidence remains behind Show Details.

### 7. Add validation

Add or update tests to ensure:

- explanation JSON parses
- all Guided Mode check IDs have explanation coverage or an intentional fallback
- cloud-safe report schema parses
- cloud-safe report excludes obvious local path patterns and usernames
- PowerShell parser checks pass
- existing smoke/safety tests still pass

## Safety constraints

- No live registry writes.
- No Halo JSON writes.
- No RTSS writes.
- No process kills.
- No auto-reboot.
- No OpenAI API key required.
- No Vercel deployment required.
- Local app must work offline.

## Acceptance checks

- Guided Mode opens.
- Latest report-style values produce `Good` for known-good Windows graphics settings.
- Cleanup-only pending reboot is Review.
- Player report is readable without raw path spam.
- Cloud-safe report exists and is sanitized.
- Advanced details still preserve developer evidence locally.
- CI/tests pass.
