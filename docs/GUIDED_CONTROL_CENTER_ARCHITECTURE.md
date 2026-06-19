# GPTOPT Guided Control Center Architecture

GPTOPT must become a product, not a script pile. The default experience should not ask the user to interpret registry keys, process names, or raw audit lines.

## Product goal

The first screen answers one question:

> Am I ready to play?

The answer must be one of:

- Ready to play
- Ready, with review items
- Fix these first

## User model

The default user does not know what these mean:

- `HwSchMode`
- `OverlayTestMode`
- `NtSetTimerResolution`
- `SyncLimiter`
- `ApplicationDetectionLevel`
- `SpecControlSettings.json`
- `GameDVR_Enabled`

GPTOPT must translate those into plain language before showing technical detail.

## UI layers

### Guided mode

Default mode. Uses plain language cards:

- Area
- Status
- What this means
- What to do
- Risk
- Undo path

Examples:

| Area | Status | Plain language | Action |
|---|---|---|---|
| Latency Timer | Good | Low-latency timer is active. | No action needed. |
| RTSS FPS Cap | Good | Halo is capped at 240 FPS by RTSS. | No action needed. |
| Audio / Sonar | Review | Sonar device exists, but the app is not running. | Open SteelSeries GG if headset routing sounds wrong. |
| Windows Gaming | Fix | A Windows capture or graphics setting is outside the baseline. | Apply Windows Essentials. |

### Advanced mode

Advanced mode can show raw values, paths, and registry keys. It must never be the default screen.

## Action model

Every action button must include:

- What it changes
- Why it matters
- Whether it requires admin
- Whether it requires reboot
- What backup is created
- How to undo

Button names must be specific. Avoid vague labels like `Apply`.

Good labels:

- Start Timer Holder
- Apply RTSS Halo 240 Cap
- Apply Halo Display Baseline
- Start Session Apps
- Open Sonar
- Open Flydigi
- Save Report

Bad labels:

- Fix
- Optimize
- Apply Tweaks
- Boost FPS

## Knowledge system

Guided mode should use `Knowledge/gptopt-health-model.json` as the user-facing translation layer. This keeps product decisions out of random chat replies and makes GPTOPT improve over time.

## Default launcher path

The one-line bootstrap should install/update and launch Guided Mode first:

```text
gptopt.ps1
  -> Run-GPTOPT.ps1
    -> Scripts/Invoke-GPTOPTGuidedControlCenter.ps1
      -> Scripts/Invoke-GPTOPTControlCenter.ps1 for advanced tools
```

## Non-goals

- Do not make users read full PowerShell transcripts to know what to do.
- Do not default to telemetry/recording workflows.
- Do not hide risk or undo information.
- Do not create more issue spam before inspecting, building, and testing.

## Build order

1. Guided report interpreter.
2. Guided live audit cards.
3. Recommended action queue.
4. Safe action wrappers with backup metadata.
5. Full app packaging.
6. Signed executable / installer.
