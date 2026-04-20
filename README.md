# GPTOPT Gaming Assistant

Central repository for a custom gaming optimization assistant focused on Windows 11 tuning, latency reduction, benchmarking, NVIDIA profile work, and practical troubleshooting for performance-sensitive PC gaming setups.

This repo now serves as the **single hub** for the earlier experimental repositories:

- **PowerShell-Utility** → merged here as a real script under `Scripts/Ultimate-Utility.ps1`
- **nvidiaProfileInspector** → treated as an upstream companion/reference project for profile-level NVIDIA tuning
- **Gpttest-** → treated as a learning/reference source for prompt-engineering patterns, not bundled content

## What this repo is

This repository is for building and maintaining a custom GPT / assistant that can:

- analyze gaming-performance issues
- suggest safe Windows 11 tuning steps
- explain NVIDIA Profile Inspector concepts and profile strategy
- guide benchmarking with CapFrameX, RTSS, PresentMon, and similar tools
- provide rollback-aware scripts and concise operating guidance

## Included files

- `instructions.txt` — core assistant behavior and response format
- `prompt_examples.json` — sample user prompts / conversation starters
- `GPT_Builder_Setup_Guide.txt` — setup guide for importing into a custom GPT
- `Scripts/Ultimate-Utility.ps1` — interactive PowerShell utility launcher
- `docs/UPSTREAM_SOURCES.md` — explains how the old repos map into this one

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
- CapFrameX, RTSS, PresentMon, event logs, and basic audit scripts
- before/after verification structure

### Prompt / assistant behavior
- response structure for high-signal technical help
- reusable prompt patterns for diagnostics, rollback, and profile generation

## Notes on upstream content

This repository intentionally **does not re-bundle third-party notebook/course content** from other projects. When outside repos are useful, they are documented as references in `docs/UPSTREAM_SOURCES.md`.

## Recommended next additions

- example `.nip` profiles
- rollback `.reg` bundles
- benchmark-analysis templates
- example CapFrameX / PresentMon interpretation guides
- a `Scripts/Profiles` folder for safe preset scripts
