# GPTOPT Architecture

GPTOPT is organized as a layered Windows gaming optimization toolkit.

## Layers

### 1. Audit Layer

Collects read-only system, game, display, audio, controller, and tool state.

Expected future scripts:

- `Scripts/Invoke-GPTOPTAudit.ps1`
- `Scripts/Test-GPTOPTEnvironment.ps1`
- `Scripts/Get-GPTOPTState.ps1`

### 2. Evidence Layer

Captures and packages evidence for analysis.

Current module:

- `HaloSight/`

HaloSight is responsible for session start/stop, evidence collection, CapFrameX package detection, OBS video detection, and upload package generation.

### 3. Profile Layer

Defines optimization profiles as data instead of hardcoded GUI behavior.

Expected future files:

- `Profiles/profiles.json`
- `Profiles/competitive-halo.json`
- `Profiles/general-gaming.json`
- `Profiles/recording-obs.json`

### 4. Apply Layer

Applies scoped, reversible changes.

Current script:

- `Scripts/Invoke-GPTOPTProfile.ps1`

All apply behavior should have a rollback path and should clearly identify admin requirements and reboot requirements.

### 5. Rollback Layer

Restores previous state from saved snapshots or documented defaults.

### 6. GUI Layer

The GUI should call backend scripts and read structured output. It should not directly own risky system modification logic.

## Safety Boundaries

GPTOPT should not inject into games, read game memory, manipulate input, silently kill browsers, force reboot, or silently disable security features.

## Design Principle

GPTOPT should prove changes with reports and evidence, not just apply tweaks.
