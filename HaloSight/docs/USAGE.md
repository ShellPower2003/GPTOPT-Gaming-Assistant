# HaloSight Usage

## GUI-first workflow

1. Run `GPTOPT_LAUNCHER.cmd`.
2. The HaloSight GUI opens.
3. Click `Settings` if you need to change session folders, evidence limits, watched processes, watched services, or upload behavior.
4. Click `Start Session` before a match.
5. Capture gameplay with your normal tools.
6. Click `Stop + Build Upload` after the match.
7. Click `Copy Upload Zip Path` or `Open Upload Folder`.
8. Upload the generated `_UPLOAD.zip` for analysis.

The normal workflow happens inside the GUI. There is no normal-user launcher menu for Start, Stop, Status, or Settings.

## Advanced manual fallback

These launchers remain available for development and fallback troubleshooting:

```text
HaloSight_START.cmd
HaloSight_STOP.cmd
HaloSight_STATUS.cmd
HaloSight_REPORT.cmd
```

You can also call the script directly:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\HaloSight.ps1 -Mode status
```

Use the GUI first unless you are deliberately debugging the package.
