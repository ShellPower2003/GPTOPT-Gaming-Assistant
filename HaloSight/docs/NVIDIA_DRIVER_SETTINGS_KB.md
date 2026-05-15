# NVIDIA Driver Settings Knowledge Base

This document is the starting knowledge base for GPTOPT/HaloSight NVIDIA driver-profile work.

The purpose is to track NVIDIA driver settings, NVIDIA Profile Inspector behavior, `.nip` backup/restore workflows, and which settings are safe to audit versus risky to change.

## Source links

Primary references:

- PCGamingWiki: Nvidia Profile Inspector
  - https://www.pcgamingwiki.com/wiki/Nvidia_Profile_Inspector
- NVIDIA NVAPI Driver Settings header reference
  - https://archive.docs.nvidia.com/gameworks/content/gameworkslibrary/coresdk/nvapi/NvApiDriverSettings_8h.html
- Orbmu2k NVIDIA Profile Inspector repository
  - https://github.com/Orbmu2k/nvidiaProfileInspector

## Tool role

NVIDIA Profile Inspector is an advanced Windows tool for viewing and editing NVIDIA global and per-application driver profiles through NVIDIA's driver settings/profile APIs.

For GPTOPT, this should be treated as an external advanced module, not a default optimizer path.

GPTOPT should initially do three things:

1. Detect whether NVIDIA Profile Inspector is installed or available.
2. Help export/backup profiles before any profile experimentation.
3. Document and audit relevant settings without blindly applying them.

## Safety rules

Do not implement blind driver-profile writes.

Required safety model:

- Audit first.
- Export current profile or customized profiles before changes.
- Prefer game-specific profile changes over global changes.
- Require explicit confirmation before any profile import/write.
- Log old and new values.
- Keep `.nip` backups outside the NVIDIA driver folder.
- Provide a restore path.
- Treat hidden, undocumented, deprecated, or driver-version-specific settings as Advanced.

Do not add:

- automatic global profile resets
- silent `.nip` imports by default
- driver-profile writes during HaloSight capture
- unsupported NVAPI experimentation in normal runtime
- anti-cheat bypasses
- game memory reads
- input manipulation

## NVIDIA Profile Inspector workflow for GPTOPT

Recommended UI flow:

1. NVIDIA / Display page detects NVIDIA GPU and driver.
2. Advanced NVIDIA Profile page detects `nvidiaProfileInspector.exe`.
3. User clicks `Export Current NVIDIA Profiles`.
4. GPTOPT stores the backup under the session/report folder.
5. Only then are optional profile experiments available.
6. User can restore imported/exported `.nip` backups.

## Useful NVIDIA Profile Inspector capabilities

Track these in GPTOPT as supported external workflows:

- View global profile.
- View per-application profiles.
- Search/filter settings.
- Add/remove application executables from a profile.
- Export `.nip` profile backups.
- Import `.nip` profiles.
- Export customized profiles.
- Restore one setting, one profile, or driver defaults.
- Use command line only for explicit backup/import workflows.

## Important command-line capabilities

Known useful commands to account for:

```text
nvidiaProfileInspector.exe -exportCustomized
nvidiaProfileInspector.exe -silentImport profile.nip
nvidiaProfileInspector.exe profile.nip
```

GPTOPT should never use silent import without a visible confirmation and backup.

## Relevant setting categories

The NVAPI driver settings reference exposes many setting names and IDs. GPTOPT should categorize them for audit/reporting.

### Frame pacing / latency / sync

Examples:

- Frame Rate Limiter
- Vertical Sync
- Vertical Sync Tear Control
- Variable Refresh Rate
- G-SYNC / VRR app override
- Maximum pre-rendered frames
- Virtual Reality pre-rendered frames
- Low-latency related profile settings if exposed by current driver/profile metadata

GPTOPT handling:

- Audit and document current values first.
- Do not write automatically.
- Prefer RTSS limiter authority for current Halo workflow unless user explicitly tests otherwise.

### Power / performance

Examples:

- Power management mode
- Maximum GPU Power
- PowerThrottle / PCIe compliance related values
- Battery Boost / idle application FPS limits

GPTOPT handling:

- Audit current state.
- Flag laptop/battery settings separately.
- Do not force global maximum performance by default.

### Texture filtering / image quality

Examples:

- Texture filtering quality
- LOD Bias
- Negative LOD Bias
- Anisotropic filtering mode/level
- Anisotropic sample optimization
- Trilinear optimization
- Bilinear anisotropic optimization

GPTOPT handling:

- Treat as per-game profile experiments.
- Avoid global changes.
- Require screenshot/performance comparison notes.

### Shader cache

Examples:

- Shader Cache
- Shader Cache maximum size
- Shader cache path related values

GPTOPT handling:

- Audit/report only initially.
- Do not clear shader cache automatically during session capture.

### Antialiasing / FXAA / MFAA

Examples:

- Antialiasing mode/setting
- Antialiasing gamma correction
- Transparency supersampling/multisampling
- FXAA enable
- MFAA / sample interleaving

GPTOPT handling:

- Audit/report only.
- Most modern games should be controlled in-game unless a profile experiment is intentional.

### OpenGL / Vulkan / present method

Examples:

- Vulkan/OpenGL present method
- OpenGL threaded optimization
- OpenGL triple buffering
- OpenGL swap interval

GPTOPT handling:

- Mostly irrelevant for Halo Infinite, but useful for future game support.
- Keep as knowledge-base mapping only.

### DLSS / upscaling / modern driver overrides

Examples:

- NVIDIA quality upscaling
- DLSS / ray reconstruction / frame generation override entries when exposed by installed driver/Profile Inspector metadata

GPTOPT handling:

- Driver-version-specific.
- Advanced only.
- Never assume availability.

## Halo Infinite baseline policy

For current Halo Infinite competitive testing:

- Do not use NVIDIA Profile Inspector as the first fix path.
- Use CapFrameX/PresentMon/HaloSight evidence first.
- Keep RTSS as frame-cap authority unless testing says otherwise.
- Keep browser safe because ChatGPT may be open during troubleshooting.
- Avoid global driver-profile changes.
- Prefer export/import `.nip` workflow for controlled profile experiments.

## GPTOPT implementation plan

### Phase 1: Knowledge base and detection

- Add this document.
- Detect `nvidiaProfileInspector.exe` path.
- Detect NVIDIA GPU/driver.
- Detect `nvidia-smi` availability.
- Add dashboard card: NVIDIA Profile Inspector found/missing.

### Phase 2: Backup-only integration

- Add button: Export customized NVIDIA profiles.
- Store backup in current HaloSight session folder.
- Add backup path to report.
- Add restore instructions, not automatic restore yet.

### Phase 3: Profile experiment manager

- Add profile experiment records:
  - game/profile name
  - driver version
  - GPU
  - changed settings
  - old value
  - new value
  - backup file
  - test run ID
  - CapFrameX/HaloSight result

### Phase 4: Safe import/restore

- Explicit `.nip` import with confirmation.
- Restore selected backup.
- Never silent-import without user confirmation.

## Notes for Codex/AI contributors

When enhancing GPTOPT NVIDIA functionality:

- Use these sources as references, not copied code.
- Do not scrape or vendor NVIDIA Profile Inspector internals into GPTOPT unless license-compatible and explicitly reviewed.
- Prefer calling external tools or documenting workflows before implementing direct NVAPI writes.
- Any direct NVAPI integration belongs in an Advanced module with backups, tests, and explicit warnings.
