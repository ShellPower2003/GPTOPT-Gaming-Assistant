# Contributor Guide: GPTOPT Gaming Assistant

## 📂 Project Overview
This repository contains tools, tweaks, and performance configurations designed to help users optimize their Windows gaming experience.

### Key Files:
- `disable_vbs.ps1`: Disables Virtualization-Based Security for performance gains.
- `esports_mode.bat`: Applies low-latency gaming tweaks.
- `quality_mode.bat`: Reverts to high-quality default Windows settings.
- `reset_tweaks.bat`: Resets all tweaks to defaults.
- `*.reg`: Registry tweaks for performance or latency.
- `*.nip`: NVIDIA Inspector profiles for GPU tuning.
- `README.md`: User instructions and optimization theory.
- `capframex_*`: Benchmark and analysis files for CapFrameX.

## 🛠️ Setup Instructions
No installation required. This is a portable toolkit.

## ✅ Validation Steps
1. Manually inspect registry and script changes.
2. Run each `.bat` or `.ps1` with admin privileges in a test VM or sandbox.
3. Confirm system behavior post-reboot.
4. Benchmark using `CapFrameX` with `capframex_template_testplan.txt`.

## 🔍 Testing Notes
- Review `.nip` profiles via NVIDIA Profile Inspector before applying.
- Always back up the registry before running `.reg` files.
- Use `reset_tweaks.bat` to revert any active modifications.

## 🧠 Prompting Codex
- Ask it to optimize or audit batch or PowerShell scripts.
- Ask it to validate registry keys.
- Ask for performance testing suggestions with CapFrameX.
- Tell it where to make changes: `bat`, `ps1`, or `.reg` files only.

## 🧪 PR Format
```
[script] Improve latency tweaks in esports_mode.bat
```

## 🧼 Cleanup
- Revert changes before testing other modes
- Use reset script when switching modes
