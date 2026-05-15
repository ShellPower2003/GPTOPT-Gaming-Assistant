param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$GuiScript = Join-Path $Root 'scripts\HaloSightGUI.ps1'
$ConfigPath = Join-Path $Root 'config\halosight.config.json'

function Assert($Condition, $Message){
    if(-not $Condition){ throw $Message }
}

function Assert-Parses($Path){
    $code = Get-Content -Raw -LiteralPath $Path
    $null = [scriptblock]::Create($code)
}

Assert-Parses $CoreScript
Assert-Parses $GuiScript

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
Assert ($config.Project -eq 'GPTOPT-HaloSight') 'Config project name mismatch.'

$oldUserProfile = $env:USERPROFILE
$testHome = Join-Path $env:TEMP ("HaloSightSmoke_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testHome | Out-Null
try{
    $env:USERPROFILE = $testHome
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CoreScript -Mode status | Out-Host
    Assert ($LASTEXITCODE -eq 0) 'HaloSight.ps1 -Mode status failed.'
}finally{
    $env:USERPROFILE = $oldUserProfile
    Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
}

$allText = @(
    Get-Content -Raw -LiteralPath $CoreScript
    Get-Content -Raw -LiteralPath $GuiScript
) -join "`n"

Assert ($allText -notmatch '(?i)\bStop-Process\b') 'Stop-Process call found.'
Assert ($allText -notmatch '(?i)\btaskkill\b') 'taskkill call found.'
Assert ($allText -notmatch '(?i)\.CloseMainWindow\s*\(') 'CloseMainWindow call found.'
Assert ($allText -notmatch '(?i)\.PriorityClass\s*=') 'Process priority assignment found.'
Assert ($allText -notmatch '(?i)HaloInfinite[\s\S]{0,120}\.PriorityClass\s*=') 'HaloInfinite priority modification found.'
Assert ($allText -notmatch '(?i)(chrome|msedge)[\s\S]{0,120}(Stop-Process|taskkill|CloseMainWindow)') 'Browser closure targeting found.'
Assert ($allText -notmatch '(?i)(ReadProcessMemory|WriteProcessMemory|OpenProcess|CreateRemoteThread|VirtualAllocEx)') 'Process injection or memory-read API found.'
Assert ($allText -notmatch '(?i)(SendInput|mouse_event|keybd_event)') 'Input manipulation API found.'

Write-Host '[OK] HaloSight smoke test passed.' -ForegroundColor Green
