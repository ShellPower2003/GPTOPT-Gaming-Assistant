# NVIDIA Driver Settings Safety KB

This file is the safety policy source for GPTOPT NVIDIA / Display work.

## PR #9 Scope

The NVIDIA / Display page is read-only. It may detect and display:

- NVIDIA GPU name and driver version through Windows inventory APIs.
- `nvidia-smi.exe` availability through command discovery.
- NVIDIA Profile Inspector availability through a configured path or command discovery.
- HAGS and MPO registry values through reads only.
- Active display resolution and refresh when Windows exposes it safely.
- RTSS and MSI Afterburner process presence.

## Prohibited In This Foundation PR

- No `.nip` import.
- No `silentImport` execution.
- No direct NVAPI writes.
- No NVIDIA global profile changes.
- No registry writes for HAGS, MPO, or driver settings.
- No process termination.
- No browser cleanup.
- No reboot, logoff, or shutdown.

## Future Change Rules

Any future NVIDIA setting change must be audit-first, explicit, reversible, and documented with the exact setting, source, expected effect, rollback path, and validation evidence.
