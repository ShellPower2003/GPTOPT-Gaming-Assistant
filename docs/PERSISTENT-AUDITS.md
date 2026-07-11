# GPTOPT Persistent Audits

GPTOPT now separates private diagnostics from connector-readable summaries.

## Data flow

1. `Run-GPTOPTAudit.ps1` launches the collector with publishing enabled.
2. Full diagnostics are stored only under `%LOCALAPPDATA%\GPTOPT\Audits`.
3. A limited sanitized JSON and Markdown report is generated.
4. GPTOPT creates or updates one GitHub issue named `[GPTOPT-AUDIT:<machine-key>] Latest PC Audit`.
5. ChatGPT can read that issue through the connected GitHub connector when asked to analyze the latest GPTOPT audit.

The same issue is updated on every run, so the repository is not flooded with audit issues.

## Run it

From the repository root:

```powershell
.\Run-GPTOPTAudit.ps1
```

Run locally without publishing:

```powershell
.\Run-GPTOPTAudit.ps1 -NoPublish
```

The script displays a real percentage-complete progress bar and ends at 100%.

## Requirements for automatic publishing

- GitHub CLI installed as `gh.exe`
- `gh auth login` completed
- Permission to create and edit issues in `ShellPower2003/GPTOPT-Gaming-Assistant`

## Privacy boundary

The GitHub summary contains only the fields needed for routine performance triage:

- Windows edition and build
- BIOS vendor/version
- CPU and GPU model
- memory capacity
- active display resolution and refresh rate
- power plan
- Game Mode, Game DVR, HAGS, and MPO registry states
- NVIDIA driver version
- controller-presence flag
- counts of recent errors, problem devices, and reboot indicators
- free space on the system drive

The published report intentionally excludes:

- usernames and profile paths
- computer name
- IP and MAC addresses
- serial numbers
- device instance IDs
- event message bodies
- process paths and command lines
- registry exports
- file listings
- Wi-Fi profiles, credentials, and tokens

## Local storage layout

```text
%LOCALAPPDATA%\GPTOPT\Audits\
├── latest.json
├── latest\
│   ├── GPTOPT-SanitizedReport.json
│   └── GPTOPT-SanitizedReport.md
└── GPTOPT-YYYYMMDD_HHMMSS\
    ├── GPTOPT-SanitizedReport.json
    ├── GPTOPT-SanitizedReport.md
    └── raw\
        ├── private-snapshot.json
        ├── signed-drivers.csv
        └── powercfg.txt
```

The default retention limit is 20 complete local audit runs.

## ChatGPT usage

After running the audit, ask:

```text
@GitHub analyze my latest GPTOPT audit
```

ChatGPT can locate the open `[GPTOPT-AUDIT:*]` issue and analyze its current sanitized contents.
