# HaloSight Usage

## GUI-first workflow

1. Run `GPTOPT_LAUNCHER.cmd`.
2. The HaloSight GUI opens.
3. Click `Ready for Halo?` to refresh the dashboard cards.
4. Click `Settings` if you need to change session folders, evidence limits, watched processes, watched services, or upload behavior.
5. Click `Start Session` before a match.
6. Play the match and capture gameplay with your normal tools.
7. Click `Stop + Build Upload` after the match.
8. Click `Copy Upload Zip Path` or `Open Upload Folder`.
9. Upload the generated `_UPLOAD.zip` for analysis.

The normal workflow happens inside the GUI. There is no normal-user launcher menu for Start, Stop, Status, or Settings.

The dashboard cards show Active Session, Halo, RTSS, MSI Afterburner, CapFrameX, OBS, Timer Resolution, Gaming Services, Audio/Sonar, Problem Devices, Pending Reboot/Rename, and Latest Upload Zip with GOOD/WARN/BAD/UNKNOWN badges. `Ready for Halo?` and `Refresh Status` are read-only checks.

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
