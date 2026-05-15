# Contributing

## Project Direction

GPTOPT is an evidence-driven gaming optimization toolkit. Changes should improve reliability, safety, reporting, or measurable game performance workflows.

## Contribution Rules

- Keep pull requests small and focused.
- Prefer audit/report behavior before apply/fix behavior.
- Do not add hidden system changes.
- Do not add forced reboot, shutdown, or logoff behavior.
- Do not kill browsers by default.
- Do not change game process priority unless explicitly approved in a scoped experiment.
- Do not add game injection, memory reads, or input manipulation.

## Required Checks

Before opening a pull request, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File HaloSight\tests\smoke_test.ps1
```

Also verify PowerShell files parse:

```powershell
Get-ChildItem -Recurse -File -Filter *.ps1 | ForEach-Object {
    [scriptblock]::Create((Get-Content -Raw -LiteralPath $_.FullName)) | Out-Null
}
```

## Pull Request Style

Every pull request should include:

- Summary
- Scope
- Non-goals
- Test plan
- Risk notes
