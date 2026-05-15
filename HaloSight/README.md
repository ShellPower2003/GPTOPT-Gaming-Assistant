# GPTOPT HaloSight GUI v0.4

External Halo Infinite session recorder/analyzer helper for the existing GPTOPT gaming assistant repo.

It does not inject into Halo, read game memory, alter input, or touch anti-cheat-sensitive areas. It only captures external Windows/game state, files you already create with CapFrameX/OBS/NVIDIA, service status, timer resolution, and process snapshots.

## Use

Run from the GUI:

```text
HaloSight_GUI.cmd
```

Or run from PowerShell / double-click CMD files:

```text
HaloSight_START.cmd
HaloSight_STATUS.cmd
HaloSight_STOP.cmd
```

Workflow:

1. Start RTSS/MSI Afterburner/CapFrameX/OBS or NVIDIA recording as normal.
2. Run `HaloSight_START.cmd` before the match.
3. Play Halo.
4. Stop CapFrameX/video before scoreboard/menu when possible.
5. Run `HaloSight_STOP.cmd`.
6. Upload the generated `_UPLOAD.zip` from `Documents\GPTOPT\HaloSight\sessions\...`.

## What it collects

- Halo/RTSS/MSI Afterburner/CapFrameX process state
- Timer resolution
- Gaming/Xbox service state
- HAGS/MPO/Game DVR registry state
- Audio/Sonar process and endpoint state
- Problem devices
- Recent system errors excluding browser updater noise
- New CapFrameX and video files created during session
- Optional compressed MP4 clip if ffmpeg is available
- Session report markdown + JSON/CSV logs

## v0.3 optimization notes

- Evidence roots are scanned once per root instead of once per file pattern.
- Evidence copying is capped by `Evidence.MaxFiles` and `Evidence.MaxFileMB` to avoid accidental huge upload bundles.
- Optional tools resolve from the package first, then from `PATH`.
- Video compression falls back to CPU x264 if NVIDIA NVENC is unavailable.
- Reports now show the actual session folder name.

## v0.4 GUI notes

- Added `HaloSight_GUI.cmd`, a WPF button wrapper for start, stop, status, report, opening the latest session, opening the upload folder, and copying the latest upload zip path.
- The GUI reads `config\halosight.config.json` so it uses the same session root as the optimized capture script.

## Tests

Run the smoke test from the `HaloSight` folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests\smoke_test.ps1
```

The smoke test parses both PowerShell scripts, loads the JSON config, runs `scripts\HaloSight.ps1 -Mode status`, and checks that the package does not include process closure, Halo priority modification, injection, memory reads, or input manipulation behavior.

## Safety

It does not close Chrome/Edge because the browser may be the ChatGPT session. It does not change Halo priority. It does not reboot.
