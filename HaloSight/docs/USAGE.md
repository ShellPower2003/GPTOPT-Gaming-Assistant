# HaloSight Usage

## GUI workflow

1. Run `HaloSight_GUI.cmd`.
2. Open `Settings` if you want to change session folders, evidence limits, watched processes, watched services, or upload behavior.
3. Select `Start Session` before a match.
4. Capture gameplay with your normal tools.
5. Select `Stop + Build Upload` after the match.
6. Upload the generated `_UPLOAD.zip` from the sessions folder for analysis.

## Command workflow

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\HaloSight.ps1 -Mode status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\HaloSight.ps1 -Mode start
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\HaloSight.ps1 -Mode stop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\HaloSight.ps1 -Mode report
```

`start` creates a session and captures a start snapshot. `stop` captures a stop snapshot, copies evidence, builds a report, and creates the upload zip.
