# GUI Notes

This GUI is a PowerShell WPF wrapper around HaloSight.ps1 and HaloSightSettings.ps1.

It calls the optimized capture script with `-Mode`, opens a settings window for `config\halosight.user.json`, and reads merged defaults/user settings for the session root and upload behavior.

It is intentionally external and safe:
- no DLL injection
- no process memory reads
- no anti-cheat bypass
- no browser closing
- no Halo priority edits
