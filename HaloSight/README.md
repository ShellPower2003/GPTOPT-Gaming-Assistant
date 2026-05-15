# GPTOPT HaloSight GUI v0.4

HaloSight is an external Halo Infinite session recorder/analyzer helper for the GPTOPT Gaming Assistant repo.

It captures Windows/game-adjacent state, process and service snapshots, device status, recent system errors, and evidence files created by tools you already use such as CapFrameX, OBS, or NVIDIA recording.

## Run From The GitHub Repo

From the repo root:

```text
GPTOPT_LAUNCHER.cmd
```

Menu options:

1. HaloSight GUI
2. HaloSight Start
3. HaloSight Stop + Build Upload
4. HaloSight Status
5. HaloSight Settings
6. Run Smoke Test

You can also run from the `HaloSight` folder:

```text
HaloSight_GUI.cmd
```

## GUI Workflow

1. Run `HaloSight_GUI.cmd`.
2. Open `Settings` and confirm the session root, evidence folders, limits, watched processes, and watched services.
3. Select `Start Session` before the match.
4. Play and capture normally.
5. Select `Stop + Build Upload` after the match.
6. Upload the generated `_UPLOAD.zip` from the sessions folder.

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

## Upload Package Workflow

`Stop + Build Upload` captures a stop snapshot, copies new matching evidence files, optionally compresses the newest copied video, writes `HaloSight_Report.md`, and creates a session `_UPLOAD.zip`.

## Tests

Run from the `HaloSight` folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests\smoke_test.ps1
```

The smoke test parses all PowerShell files, validates all JSON files, loads merged settings, exercises settings reset/save/load, runs `scripts\HaloSight.ps1 -Mode status`, and scans runtime scripts for prohibited behavior.

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

## Known Limitations

- It analyzes files and snapshots you create around a session; it does not inspect live game internals.
- Video compression requires `ffmpeg.exe`.
- Missing evidence usually means the configured folders do not match where your capture tools wrote files.
- The GUI uses Windows PowerShell/WPF and is intended for Windows.
