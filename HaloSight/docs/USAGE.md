# HaloSight Usage

## GUI-first workflow

1. Run `GPTOPT_LAUNCHER.cmd`.
2. The GPTOPT Control Center opens.
3. Click `Ready for Halo?` to refresh the dashboard cards.
4. Click `Settings` if you need to change session folders, evidence limits, watched processes, watched services, or upload behavior.
5. Click `Start Session` before a match.
6. Play the match and capture gameplay with your normal tools.
7. Click `Stop + Build Upload` after the match.
8. Click `Copy Upload Zip Path` or `Open Upload Folder`.
9. Upload the generated `_UPLOAD.zip` for analysis.

The normal HaloSight workflow happens inside the GUI on the `HaloSight` page. There is no normal-user launcher menu for Start, Stop, Status, or Settings.

The top-level pages are `Dashboard`, `HaloSight`, `NVIDIA / Display`, `Audio / Sonar`, `Controller / HID`, `Windows Gaming Health`, `Apps / Tools`, `Reports`, and `Advanced / Revert`.

The dashboard cards show Active Session, Halo, RTSS, MSI Afterburner, CapFrameX, OBS, Timer Resolution, Gaming Services, Audio/Sonar, Problem Devices, Pending Reboot/Rename, Latest Upload Zip, NVIDIA GPU, NVIDIA Driver, and NVIDIA Profile Inspector with GOOD/WARN/BAD/UNKNOWN badges. `Ready for Halo?` and `Refresh Status` are read-only checks.

Start, Stop, Status, and Rebuild Report run in the background. The GUI remains usable while `Stop + Build Upload` packages evidence, with action buttons disabled until the command completes.

## NVIDIA / Display

The `NVIDIA / Display` page is read-only in this PR. It detects NVIDIA GPU and driver information, `nvidia-smi.exe`, NVIDIA Profile Inspector, HAGS, MPO, active display information, RTSS, and MSI Afterburner without importing profiles or changing driver settings.

To override NVIDIA Profile Inspector detection, set `OptionalTools.NvidiaProfileInspectorPath` in `config\halosight.user.json`.

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
