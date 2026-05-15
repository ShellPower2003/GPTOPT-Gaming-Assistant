# GUI Notes

This GUI is a PowerShell WPF wrapper around HaloSight.ps1.

It calls the optimized capture script with `-Mode`, and it reads `config\halosight.config.json` for the session root.

It is intentionally external and safe:
- no DLL injection
- no process memory reads
- no anti-cheat bypass
- no browser closing
- no Halo priority edits
