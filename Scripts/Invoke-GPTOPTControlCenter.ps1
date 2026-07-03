param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$LegacyControlCenter = Join-Path $PSScriptRoot 'Invoke-GPTOPTAppGUI.ps1'
$HaloSightGui = Join-Path $Root 'HaloSight\scripts\HaloSightGUI.ps1'

if (Test-Path -LiteralPath $LegacyControlCenter) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LegacyControlCenter
    exit $LASTEXITCODE
}

if (Test-Path -LiteralPath $HaloSightGui) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightGui
    exit $LASTEXITCODE
}

throw 'No advanced control center entry was found.'
