# GPTOPT Native App

GPTOPT is an explainable Windows gaming performance assistant organized around **Prepare → Understand → Measure → Experiment → Keep or Roll Back → Verify**.

## Product promise

GPTOPT should answer five questions without forcing the user to interpret raw Windows data:

1. Can I play now?
2. What evidence actually matters?
3. What changed?
4. Did the change measurably help?
5. Can I undo it safely?

## Current capabilities

- Persistent local PC audits with optional sanitized GitHub publishing and read-back verification
- Relevance-weighted readiness verdicts instead of generic Windows error totals
- Decision-first diagnostics separating blocking, review, and informational findings
- Specific WHEA, GPU reset, storage, controller, gaming-crash, problem-device, Flydigi, and reboot findings
- Controller evidence with provider, event ID, matched device, and timestamp
- Flydigi/Vader path validation without terminating SpaceStation or GameControllerService
- Network-quality measurement for active adapter, gateway, DNS, latency, jitter, packet loss, and route evidence
- Honest network guidance: measurement and path separation rather than unsupported registry ping claims
- Automatic discovery and ranking of recent CapFrameX/PresentMon captures
- Session analysis with duration, average FPS, 1% low, P95, P99, standard deviation, severe-hitch rates, maximum frame time, and capture-quality assessment
- Comparison confidence gates that reject short or materially different-duration runs
- Keep, rollback, or inconclusive verdicts only when equivalent-run evidence supports them
- Explainable recommendations showing current state, target state, expected impact, risk, exact change, administrator requirement, reboot requirement, and rollback behavior
- Evidence-specific Advanced Tune cards instead of generic “recent errors” cards
- Automatic rollback snapshots before supported changes
- Experiment ledger recording hypothesis, actions, before/target state, expected impact, risk, rollback path, status, and verification instruction
- Searchable, navigable, copyable, wrappable, and savable evidence reports
- Native access to controller calibration, PresentMon, Task Manager, Device Manager, Event Viewer, Windows Update, and NVIDIA App
- Windows CI that validates XAML, event-handler wiring, PowerShell, JSON, security constraints, regression contracts, native build, self-contained publish, and artifact upload

## Competitive position

GPTOPT deliberately does not try to become another opaque “one-click booster.”

- **Versus OEM hubs:** hardware control remains in vendor software; GPTOPT provides cross-vendor readiness, explanation, measurement, and rollback.
- **Versus generic optimizers:** GPTOPT refuses to call RAM clearing, blanket service disabling, registry packs, or raw event-count reduction a performance win.
- **Versus route optimizers:** GPTOPT measures gateway and Internet path quality and identifies where instability begins. It does not claim Windows tweaks can manufacture a shorter external route.
- **Versus benchmark tools:** CapFrameX and PresentMon remain authoritative capture sources; GPTOPT converts their data into comparable experiments and decisions.
- **Versus monitoring overlays:** GPTOPT connects evidence to a durable audit, a specific change, a rollback point, and a verification state.

## Product rules

GPTOPT does not use RAM-cleaner behavior, blanket service disabling, bulk driver updating, indiscriminate registry packs, automatic process-priority manipulation, game-memory access, input injection, forced reboot, or unsupported claims of improvement.

A change is not a win until:

- the before and after runs are comparable,
- multiple relevant metrics improve,
- critical guardrails do not regress,
- the result can be reproduced,
- and rollback remains available.

## Build

```powershell
Set-Location "$env:USERPROFILE\Documents\GitHub\GPTOPT-Gaming-Assistant"
.\GPTOPT_LAUNCHER.cmd
```

The published application is written to `dist\win-x64\GPTOPT.exe`.