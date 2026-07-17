param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$HaloSightSmoke = Join-Path $RepoRoot 'HaloSight\tests\smoke_test.ps1'

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightSmoke
exit $LASTEXITCODE
