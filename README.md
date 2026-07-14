# GPTOPT Gaming Assistant

GPTOPT is a native Windows gaming performance assistant built around one strict rule:

> A setting is not an improvement until equivalent evidence shows that it helped and a rollback remains available.

## What GPTOPT does

- Answers whether the PC is ready to play through a relevance-weighted readiness verdict
- Separates blocking hardware/driver evidence from review items and harmless background noise
- Detects WHEA, GPU resets, storage faults, controller-path events, gaming crashes, problem devices, and reboot causes
- Validates the Flydigi Vader 4 Pro and GameControllerService path without terminating SpaceStation
- Measures active network-path quality: adapter, gateway, DNS, latency, jitter, packet loss, and route evidence
- Discovers and analyzes recent CapFrameX or PresentMon captures automatically
- Rejects low-confidence before/after comparisons instead of manufacturing a winner
- Applies only reviewed supported settings after creating rollback data
- Records each applied change as an experiment with a hypothesis, expected impact, guardrails, rollback path, and verification requirement
- Publishes a sanitized current audit to GitHub and reads it back to verify the exact audit ID

## What GPTOPT refuses to do

- Fake RAM cleaning
- Blanket service disabling
- Bulk driver updating
- Registry-pack spam
- Automatic game process-priority manipulation
- Game-memory access or input injection
- Forced reboot
- Unsupported “lower ping” claims from Windows registry tweaks
- Calling an applied tweak a performance win without measurement

## Start

```powershell
Set-Location "$env:USERPROFILE\Documents\GitHub\GPTOPT-Gaming-Assistant"
.\GPTOPT_LAUNCHER.cmd
```

The launcher updates the native-app branch, rebuilds only when the commit changed, and opens the self-contained application.

## Product workflow

1. **Prepare** — audit the PC and return READY, READY WITH REVIEW ITEMS, or NOT READY.
2. **Understand** — open evidence-specific findings with why, impact, and next action.
3. **Measure** — analyze a Halo performance capture or network path.
4. **Experiment** — apply reviewed reversible changes with a recorded hypothesis.
5. **Verify** — re-audit and compare equivalent runs.
6. **Keep or Roll Back** — retain only reproduced improvements.

## Product differentiation

GPTOPT is not an OEM control panel, generic cleaner, route-selling VPN, or benchmark viewer. It connects system evidence, controller state, network measurements, performance captures, applied changes, rollback data, and verification into one durable workflow.

Vendor tools remain authoritative for vendor hardware controls. CapFrameX and PresentMon remain authoritative capture sources. GPTOPT turns those sources into decisions and preserves the evidence behind them.

See [`docs/NATIVE-APP.md`](docs/NATIVE-APP.md) for the full product contract.