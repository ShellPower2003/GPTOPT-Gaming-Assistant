# GPTOPT Native App

GPTOPT is an explainable Windows gaming utility organized around **Prepare → Understand → Measure → Apply/Roll Back → Verify**.

## Normal launch

The supported user entry point is `GPTOPT_LAUNCHER.cmd`. It updates the native-app branch, rebuilds only when the commit changed, records the built commit, and opens the native executable. Users should not need to remember Git or `dotnet` commands.

## Current capabilities

- Persistent local PC audits with verified sanitized GitHub publishing
- Gaming readiness based on relevant evidence rather than raw Windows error volume
- Decision-first targeted diagnostics with blocking, review, and informational findings
- Controller-event evidence that records provider, event ID, device match, and timestamp
- Explainable recommendations showing current state, target state, impact, risk, exact action, administrator requirement, reboot requirement, and rollback behavior
- Safe Gaming Baseline and Stability Review profiles
- Automatic rollback snapshots before supported changes
- Rollback Manager that restores a selected snapshot and directs the user to verify the result
- Flydigi/Vader controller-path checks without terminating SpaceStation or GameControllerService
- Controller calibration access through Windows `joy.cpl`
- Bounded, Halo-first discovery of CapFrameX and PresentMon CSV captures
- Single-session analysis with duration, average FPS, 1% low, P95, P99, variance, severe-hitch rates, and capture-quality assessment
- Before/after comparison that refuses a keep-or-rollback verdict when capture duration or sample quality is not comparable
- Direct launch access for PresentMon, Task Manager, Device Manager, Event Viewer, Windows Update, and NVIDIA App
- Windows CI that validates PowerShell, JSON, XAML, runtime wiring, regression contracts, native build, self-contained publish, and artifact upload

## Evidence and severity rules

- **Blocking:** WHEA hardware evidence, GPU/display resets, storage faults, or active problem devices. These invalidate performance testing until resolved.
- **Review:** confirmed controller-path events, gaming-process crashes, or a real Windows Update/Component Servicing reboot requirement. These require timestamp and device correlation.
- **Informational:** background application crashes and isolated stale cleanup entries. These remain visible but do not justify a tweak or materially lower readiness.
- Raw event counts are never treated as proof by themselves.
- A single performance capture is descriptive only. A change becomes a keep or rollback candidate only after equivalent-run comparison.

## Product rules

GPTOPT does not use RAM-cleaner behavior, blanket service disabling, bulk driver updating, indiscriminate registry packs, automatic process-priority manipulation, game-memory access, input injection, or unsupported claims of improvement. GPTOPT does not reboot automatically. A change should be kept only when repeatable audit or performance evidence supports it.

## Developer build

```powershell
Set-Location "$env:USERPROFILE\Documents\GitHub\GPTOPT-Gaming-Assistant"
.\Build-GPTOPTApp.ps1 -Run
```

The self-contained application is written to `dist\win-x64\GPTOPT.exe`.
