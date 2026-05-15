param(
    [ValidateSet('menu','gui','start','stop','status','settings','test')]
    [string]$Mode = 'menu'
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$HaloSightRoot = Join-Path $Root 'HaloSight'
$HaloSightScript = Join-Path $HaloSightRoot 'scripts\HaloSight.ps1'
$HaloSightGui = Join-Path $HaloSightRoot 'scripts\HaloSightGUI.ps1'
$SmokeTest = Join-Path $HaloSightRoot 'tests\smoke_test.ps1'

function Invoke-GptOptCommand {
    param([Parameter(Mandatory=$true)][string]$CommandMode)

    switch($CommandMode){
        'gui'      { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightGui }
        'start'    { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightScript -Mode start }
        'stop'     { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightScript -Mode stop }
        'status'   { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightScript -Mode status }
        'settings' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HaloSightGui -OpenSettings }
        'test'     { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SmokeTest }
    }
}

if($Mode -ne 'menu'){
    Invoke-GptOptCommand $Mode
    exit $LASTEXITCODE
}

while($true){
    Clear-Host
    Write-Host 'GPTOPT Gaming Assistant' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '1. HaloSight GUI'
    Write-Host '2. HaloSight Start'
    Write-Host '3. HaloSight Stop + Build Upload'
    Write-Host '4. HaloSight Status'
    Write-Host '5. HaloSight Settings'
    Write-Host '6. Run Smoke Test'
    Write-Host '7. Exit'
    Write-Host ''
    $choice = Read-Host 'Select an option'

    switch($choice){
        '1' { Invoke-GptOptCommand 'gui' }
        '2' { Invoke-GptOptCommand 'start' }
        '3' { Invoke-GptOptCommand 'stop' }
        '4' { Invoke-GptOptCommand 'status' }
        '5' { Invoke-GptOptCommand 'settings' }
        '6' { Invoke-GptOptCommand 'test' }
        '7' { break }
        default { Write-Host 'Invalid option.' -ForegroundColor Yellow }
    }
    Write-Host ''
    Read-Host 'Press Enter to continue' | Out-Null
}
