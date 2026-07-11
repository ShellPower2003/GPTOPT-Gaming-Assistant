param(
    [ValidateSet('gui','legacy','test')]
    [string]$Mode = 'gui'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DesktopApp = Join-Path $Root 'Scripts\Invoke-GPTOPTDesktopApp.ps1'
$HaloSightGui = Join-Path $Root 'HaloSight\scripts\HaloSightGUI.ps1'
$SmokeTest = Join-Path $Root 'HaloSight\tests\smoke_test.ps1'

switch($Mode){
    'gui' {
        if (-not (Test-Path -LiteralPath $DesktopApp)) { throw "GPTOPT desktop application not found: $DesktopApp" }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $DesktopApp
        exit $LASTEXITCODE
    }
    'legacy' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $HaloSightGui
        exit $LASTEXITCODE
    }
    'test' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SmokeTest
        exit $LASTEXITCODE
    }
}
