# GPTOPT Gaming Assistant

Central repository for a custom gaming optimization assistant focused on Windows 11 tuning, latency reduction, benchmarking, NVIDIA profile work, and practical troubleshooting for performance-sensitive PC gaming setups.

This repo now serves as the **single hub** for the earlier experimental repositories:

- **PowerShell-Utility** → merged here as a real script and toolkit path
- **nvidiaProfileInspector** → treated as an upstream companion/reference project for profile-level NVIDIA tuning
- **Gpttest-** → treated as a learning/reference source for prompt-engineering patterns, not bundled content

## One-script entry point

Run this from PowerShell at the repo root:

`./Launch-GPTOPT.ps1`

That launcher gives you one menu for:
- a read-only system audit
- docs and templates
- preset checklist scripts
- NIP preset starter files
- registry bundle visibility
- opening the repo folder directly

## What this repo is

This repository is for building and maintaining a custom GPT / assistant that can:

- analyze gaming-performance issues
- suggest safe Windows 11 tuning steps
- explain NVIDIA Profile Inspector concepts and profile strategy
- guide benchmarking with CapFrameX, RTSS, PresentMon, and similar tools
- provide rollback-aware scripts and concise operating guidance

## Included files

- `Launch-GPTOPT.ps1` — single-entry toolkit launcher
- `instructions.txt` — core assistant behavior and response format
- `prompt_examples.json` — sample user prompts / conversation starters
- `GPT_Builder_Setup_Guide.txt` — setup guide for importing into a custom GPT
- `Scripts/Ultimate-Utility.ps1` — utility script with a read-only audit path
- `Profiles/Competitive-Latency-Baseline.ps1` — competitive tuning checklist script
- `Profiles/Visual-Quality-Baseline.ps1` — image-quality tuning checklist script
- `NIP/GPTOPT-Competitive-Latency-Baseline.nip` — competitive preset starter manifest
- `NIP/GPTOPT-Visual-Quality-Baseline.nip` — visual-quality preset starter manifest
- `NIP/GPTOPT-Balanced-Baseline.nip` — balanced preset starter manifest
- `NIP/GPTOPT-Halo-Infinite-Competitive.nip` — Halo Infinite competitive preset starter manifest
- `NIP/GPTOPT-Global-Safe-Baseline.nip` — conservative global preset starter manifest
- `NIP/README.md` — notes on current NIP validation status
- `Registry/MPO-Disable.reg` — MPO disable bundle
- `Registry/MPO-Restore.reg` — MPO restore bundle
- `Registry/README.md` — notes for registry bundle use
- `docs/UPSTREAM_SOURCES.md` — explains how the old repos map into this one
- `docs/BENCHMARK_ANALYSIS_TEMPLATE.md` — reusable benchmark comparison template
- `docs/NVIDIA_PROFILE_STRATEGY.md` — guidance for explaining and validating NPI changes
- `docs/WINDOWS_GRAPHICS_BASELINE.md` — baseline questions and validation order for Windows graphics tuning
- `docs/CAPFRAMEX_PRESENTMON_GUIDE.md` — capture-discipline guide

## Design principles

1. Prefer reversible changes first.
2. Explain tradeoffs clearly.
3. Keep risky changes explicit.
4. Validate with measurement tools.
5. Keep the assistant concise, decisive, and technically grounded.

## Scope

### Windows / OS
- gaming-oriented Windows tuning
- rollback-aware registry and service guidance
- safe-first troubleshooting paths

### GPU / NVIDIA
- practical explanation of common NPI settings
- profile strategy and profile-management workflow
- latency / frametime / scaling tradeoff guidance

### Benchmarks / diagnostics
- CapFrameX, RTSS, PresentMon, event logs, and audit scripts
- before/after verification structure
- reusable analysis templates

### Prompt / assistant behavior
- response structure for high-signal technical help
- reusable prompt patterns for diagnostics, rollback, and profile generation

## Notes on upstream content

This repository intentionally **does not re-bundle third-party notebook/course content** from other projects. When outside repos are useful, they are documented as references in `docs/UPSTREAM_SOURCES.md`.

## Current NIP status

The included `.nip` files are starter preset manifests inside this repo. They document intended profile targets cleanly, but they are **not yet validated against a real exported NVIDIA Profile Inspector `.nip` sample** from the connected source.

## Recommended next additions

- convert the starter `.nip` manifests into verified importable export-format files
- more rollback bundles once baseline handling is documented cleanly
- game-specific interpretation guides
- more targeted profile scripts
