# GPTOPT HaloSight GUI v0.4

HaloSight is an external Halo Infinite session recorder/analyzer helper for the GPTOPT Gaming Assistant repo.

It captures Windows/game-adjacent state, process and service snapshots, device status, recent system errors, and evidence files created by tools you already use such as CapFrameX, OBS, or NVIDIA recording.

## Main Workflow

From the repo or package root:

```text
GPTOPT_LAUNCHER.cmd
```

The launcher opens the HaloSight GUI directly. There is no normal-user command menu.

1. Run `GPTOPT_LAUNCHER.cmd`.
2. The GUI opens.
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

## Advanced Manual Fallback

The `HaloSight_START.cmd`, `HaloSight_STOP.cmd`, `HaloSight_STATUS.cmd`, and `HaloSight_REPORT.cmd` launchers remain available for development and manual fallback. They are not the normal user workflow; Start, Stop, Status, Report, and Settings all belong inside the GUI.

## Tests

Run from the HaloSight folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests\smoke_test.ps1
```

Or run from the repo root:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File Run-GPTOPT.ps1 -Mode test
```

The smoke test parses all PowerShell files, validates all JSON files, loads merged settings, exercises settings reset/save/load, runs `scripts\HaloSight.ps1 -Mode status`, verifies the launcher is GUI-first, and scans runtime scripts for prohibited behavior.

## Safety Guarantees

HaloSight is external capture only.

It does not:

- inject into Halo
- read game memory
- bypass anti-cheat
- manipulate input
- close or clean browsers
- change Halo priority
- terminate game, browser, capture, overlay, or chat processes
- reboot, log off, or shut down Windows

## Known Limitations

- It analyzes files and snapshots you create around a session; it does not inspect live game internals.
- Video compression requires `ffmpeg.exe`.
- Missing evidence usually means the configured folders do not match where your capture tools wrote files.
- The GUI uses Windows PowerShell/WPF and is intended for Windows.
