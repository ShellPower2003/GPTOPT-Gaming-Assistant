# GPTOPT Gaming Assistant

GPTOPT is evolving into a safe, audit-first gaming control center for Windows gaming performance work. It keeps the merged HaloSight v0.4 workflow intact while adding the foundation for WinUtil/GhostOptimizer/RyTuneX-style pages that are telemetry-driven, reversible, and conservative by default.

## Control Center Entry Point

Run this from the repo root:

```text
GPTOPT_LAUNCHER.cmd
```

The launcher opens the GUI directly. There is no normal-user Start/Stop/Status command menu.

Top-level pages in this foundation:

- Dashboard
- HaloSight
- NVIDIA / Display
- Audio / Sonar
- Controller / HID
- Windows Gaming Health
- Apps / Tools
- Reports
- Advanced / Revert

## HaloSight Workflow

HaloSight remains the active capture workflow:

1. Click `Ready for Halo?`.
2. Click `Start Session` before a match.
3. Play and capture with your normal tools.
4. Click `Stop + Build Upload`.
5. Click `Copy Upload Zip Path` or `Open Upload Folder`.

## NVIDIA / Display

The first new real page is `NVIDIA / Display`, and it is read-only in this PR. It reports:

- NVIDIA GPU detected
- NVIDIA driver version
- `nvidia-smi.exe` availability/path
- NVIDIA Profile Inspector availability/path
- HAGS current value
- MPO current value
- active display resolution/refresh when safely detectable
- RTSS detected/running
- MSI Afterburner detected/running

Set `OptionalTools.NvidiaProfileInspectorPath` in `HaloSight\config\halosight.user.json` to override NVIDIA Profile Inspector detection.

The NVIDIA safety policy source is `docs\NVIDIA_DRIVER_SETTINGS_KB.md`.

## Safety Guarantees

This foundation is audit-first. It does not:

- inject into games
- read game memory
- manipulate input
- close or clean browsers
- change Halo priority
- terminate game, browser, capture, overlay, or chat processes
- reboot, log off, or shut down Windows
- import `.nip` files
- run `silentImport`
- write NVIDIA profiles through NVAPI
- change global NVIDIA driver profiles

## Tests

Run from the repo root:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File HaloSight\tests\smoke_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-GPTOPT.ps1 -Mode test
```

The smoke test parses PowerShell, validates JSON, checks the GUI foundation and NVIDIA page functions, verifies NVIDIA detection remains read-only, and scans runtime scripts for prohibited behavior.

## Older Toolkit Content

The repo still contains earlier GPTOPT toolkit materials, prompt examples, profiles, registry notes, and benchmark docs. The Control Center foundation is now the primary user-facing direction; older advanced assets remain reference material unless explicitly wired into a safe GUI workflow.
