# GPTOPT Rollback Guide

This guide explains how to undo GPTOPT changes.

## Esports Profile Rollback

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\Invoke-GPTOPTProfile.ps1 -Mode Reset
```

This restores the previous saved state for supported services.

## Service Audit

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\Invoke-GPTOPTProfile.ps1 -Mode Audit
```

## VBS Audit

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File disable_vbs.ps1 -Audit
```

## Manual Service Restore

If needed, restore services manually:

```powershell
Set-Service -Name SysMain -StartupType Manual
Set-Service -Name DiagTrack -StartupType Automatic
Start-Service -Name DiagTrack
```

## Notes

Some Windows changes require a reboot before they fully apply.

Always benchmark before and after applying tuning changes.
