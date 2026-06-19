# GPTOPT Control Center Foundation

GPTOPT is becoming a safe, audit-first gaming control center. HaloSight remains the external Halo Infinite session recorder/analyzer helper, and PR #9 adds the first Control Center foundation around it.

It captures Windows/game-adjacent state, process and service snapshots, device status, recent system errors, and evidence files created by tools you already use such as CapFrameX, OBS, or NVIDIA recording.

## Main Workflow

From the repo or package root:

```text
GPTOPT_LAUNCHER.cmd
```

The launcher opens the GPTOPT Control Center directly. There is no normal-user command menu.

Top-level pages:

- Dashboard
- HaloSight
- NVIDIA / Display
- Audio / Sonar
- Controller / HID
- Windows Gaming Health
- Apps / Tools
- Reports
- Advanced / Revert

1. Run `GPTOPT_LAUNCHER.cmd`.
2. The Control Center opens.
3. Click `Settings` if you need to adjust folders, limits, watched processes, watched services, or upload behavior.
4. Click `Start Session` before the match.
5. Click `Stop + Build Upload` after the match.
6. Click `Copy Upload Zip Path` or `Open Upload Folder`.
7. Upload the generated `_UPLOAD.zip` from the sessions folder.

## Settings Workflow

HaloSight loads:

1. `config\halosight.default.json`
2. `config\halosight.user.json`

The user config overlays the defaults. If `halosight.user.json` is missing, HaloSight creates it from defaults.

Settings can be edited through the GUI:

- Session root
- Evidence folders
- Max evidence files
- Max file size MB
- Copy videos on/off
- Compress videos on/off
- Auto-copy upload zip path on/off
- Auto-open upload folder on/off
- Watched processes
- Watched services

The config also supports `OptionalTools.NvidiaProfileInspectorPath` for a read-only NVIDIA Profile Inspector path override.

## NVIDIA / Display

The first new Control Center page is `NVIDIA / Display`. In this PR it is read-only and reports:

- NVIDIA GPU detection
- NVIDIA driver version
- `nvidia-smi.exe` availability/path
- NVIDIA Profile Inspector availability/path
- HAGS and MPO values
- active display resolution/refresh when safely detectable
- RTSS and MSI Afterburner presence

NVIDIA safety policy lives in `docs\NVIDIA_DRIVER_SETTINGS_KB.md`. This PR does not import `.nip` files, run `silentImport`, call NVAPI writes, or change global NVIDIA profiles.

## Advanced Manual Fallback

The `HaloSight_START.cmd`, `HaloSight_STOP.cmd`, `HaloSight_STATUS.cmd`, and `HaloSight_REPORT.cmd` launchers remain available for development and manual fallback. They are not the normal user workflow; Start, Stop, Status, Report, and Settings all belong inside the GUI.

## Tests

Run from the repo root:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File HaloSight\tests\smoke_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-GPTOPT.ps1 -Mode test
```

The smoke test parses PowerShell files, validates JSON files, loads merged settings, exercises settings reset/save/load, runs `scripts\HaloSight.ps1 -Mode status`, verifies the launcher is GUI-first, verifies the Control Center/NVIDIA page foundations, and scans runtime scripts for prohibited behavior.

## Safety Guarantees

HaloSight is external capture only. NVIDIA / Display is read-only in this PR.

It does not:

- inject into Halo
- read game memory
- bypass anti-cheat
- manipulate input
- close or clean browsers
- change Halo priority
- terminate game, browser, capture, overlay, or chat processes
- reboot, log off, or shut down Windows
- import NVIDIA profiles
- change global NVIDIA driver profiles

## Known Limitations

- It analyzes files and snapshots you create around a session; it does not inspect live game internals.
- NVIDIA / Display reports what Windows and installed tools expose; it does not change settings.
- Video compression requires `ffmpeg.exe`.
- Missing evidence usually means the configured folders do not match where your capture tools wrote files.
- The GUI uses Windows PowerShell/WPF and is intended for Windows.
