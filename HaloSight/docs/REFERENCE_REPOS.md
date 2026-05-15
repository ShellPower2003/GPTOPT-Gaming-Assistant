# Reference Repos

HaloSight/GPTOPT uses public optimizer projects as architecture references, not as copied code sources.

## ChrisTitusTech/winutil

Ideas to borrow:

- PowerShell-first Windows utility structure.
- Launcher-driven workflow.
- Combined install, tweak, troubleshooting, and repair categories.
- Clear separation between UI and utility functions.
- Validation before applying changes.

GPTOPT adaptation:

- Keep the one-launcher model, but make the scope gaming-specific.
- Use modules for HaloSight, Optimizer, NVIDIA/Display, Audio/Sonar, Controller/HID, Network, Windows Health, Apps, Reports, and Settings.
- Avoid broad debloat presets. Prefer audit-first gaming fixes.

## hellzerg/optimizer

Ideas to borrow:

- Category-based optimization pages.
- Network, startup, hardware, DNS, and service inspection concepts.
- Exportable templates/profiles.
- App/tool installer style workflow.

GPTOPT adaptation:

- Profiles should be config objects: Competitive Halo, General Gaming, Recording/OBS, Safe Daily Driver, Restore Defaults.
- Every write action should be reversible and logged.
- Do not add blind service-disabling or generic debloat behavior.

## memstechtips/Winhance

Ideas to borrow:

- Modern GUI feel with cards/toggles.
- Searchable settings and quick navigation.
- App management / WinGet installer flow.
- Clear status indicators for enabled/disabled settings.

GPTOPT adaptation:

- Dashboard status cards should use GOOD/WARN/BAD.
- Settings should be editable from the GUI and saved to user config.
- Optional tools should be detected and shown as WARN if missing, not treated as fatal.

## rcmaehl/WhyNotWin11

Ideas to borrow:

- Simple compatibility/status display style.
- Clear pass/fail/warn detection rows.
- User-readable results without requiring log inspection.

GPTOPT adaptation:

- Use readable detection rows for Game Mode, HAGS, MPO, Game DVR, timer resolution, Gaming Services, Sonar/audio state, controller/HID state, and pending reboot flags.

## GPTOPT identity

GPTOPT is not a generic debloater.

GPTOPT should be:

- gaming-focused
- telemetry-driven
- audit-first
- safe-fix second
- reversible
- report-oriented
- external-only for game capture

Hard constraints:

- no Halo injection
- no game memory reads
- no anti-cheat bypass
- no input manipulation
- no browser cleanup
- no Halo priority changes
- no automatic reboot/logoff
- no blind service debloat
