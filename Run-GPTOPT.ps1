param(
    [ValidateSet('gui','test')]
    [string]$Mode = 'gui'
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$HaloSightRoot = Join-Path $Root 'HaloSight'
$HaloSightGui = Join-Path $HaloSightRoot 'scripts\HaloSightGUI.ps1'
$SmokeTest = Join-Path $HaloSightRoot 'tests\smoke_test.ps1'

switch($Mode){
    'gui' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightGui
        exit $LASTEXITCODE
    }
    'test' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SmokeTest
        exit $LASTEXITCODE
    }
}
