# GPTOPT Native App

GPTOPT is an explainable Windows gaming utility organized around **Check → Choose → Apply/Roll Back → Verify**.

## Current capabilities

- Persistent local PC audits with optional sanitized GitHub publishing
- Explainable recommendations that show current state, target state, expected impact, risk, exact change, administrator requirement, reboot requirement, and rollback behavior
- Safe Gaming Baseline and Stability Review profiles
- Automatic rollback snapshots before supported changes
- Rollback Manager that restores a selected snapshot and then directs the user to verify the result
- Targeted diagnostics for problem devices, WHEA hardware events, NVIDIA/display resets, storage events, USB/controller events, application crashes, the Flydigi/GameControllerService path, and pending reboot sources
- Controller calibration access through Windows `joy.cpl`
- Before/after CSV comparison for PresentMon or CapFrameX-style frame-time exports
- Direct launch access for PresentMon, Task Manager, Device Manager, Event Viewer, Windows Update, and NVIDIA App
- Windows CI that validates XAML, builds, publishes, and uploads the self-contained executable

## Product rules

GPTOPT does not use RAM-cleaner behavior, blanket service disabling, bulk driver updating, indiscriminate registry packs, or unsupported claims of improvement. A change should be kept only when a repeatable audit or performance comparison supports it.

## Build

```powershell
Set-Location "$env:USERPROFILE\Documents\GitHub\GPTOPT-Gaming-Assistant"
git switch agent/native-desktop-app
git pull --ff-only
Remove-Item ".\src\GPTOPT.App\bin", ".\src\GPTOPT.App\obj" -Recurse -Force -ErrorAction SilentlyContinue
.\Build-GPTOPTApp.ps1 -Run
```

The published application is written to `dist\win-x64\GPTOPT.exe`.
