param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$SettingsScript = Join-Path $Root 'scripts\HaloSightSettings.ps1'
$UserConfigPath = Join-Path $Root 'config\halosight.user.json'

function Assert($Condition, $Message){
    if(-not $Condition){ throw $Message }
}

function Assert-Parses($Path){
    $code = Get-Content -Raw -LiteralPath $Path
    $null = [scriptblock]::Create($code)
}

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1' |
    ForEach-Object { Assert-Parses $_.FullName }

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.json' |
    ForEach-Object { $null = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json }

. $SettingsScript
$configBackup = if(Test-Path -LiteralPath $UserConfigPath){ Get-Content -Raw -LiteralPath $UserConfigPath }else{ $null }
$oldUserProfile = $env:USERPROFILE
$testHome = Join-Path $env:TEMP ("HaloSightSmoke_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testHome | Out-Null

try{
    $env:USERPROFILE = $testHome

    $resetConfig = Reset-HaloSightConfig
    Assert ($resetConfig.Project -eq 'GPTOPT-HaloSight') 'Reset config project name mismatch.'

    $mergedConfig = Get-HaloSightConfig
    Assert ($mergedConfig.Project -eq 'GPTOPT-HaloSight') 'Merged config project name mismatch.'

    $mergedConfig.SessionRoot = (Join-Path $testHome 'HaloSight\sessions')
    $savedConfig = Save-HaloSightConfig $mergedConfig
    Assert ($savedConfig.SessionRoot -eq $mergedConfig.SessionRoot) 'Saved config session root mismatch.'

    $validation = Test-HaloSightConfig $savedConfig
    Assert $validation.IsValid ('Settings validation failed: ' + ($validation.Errors -join '; '))

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CoreScript -Mode status | Out-Host
    Assert ($LASTEXITCODE -eq 0) 'HaloSight.ps1 -Mode status failed.'
}finally{
    $env:USERPROFILE = $oldUserProfile
    if($null -ne $configBackup){
        $configBackup | Out-File -FilePath $UserConfigPath -Encoding UTF8
    }else{
        Remove-Item -LiteralPath $UserConfigPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
}

$runtimeFiles = Get-ChildItem -LiteralPath $Root -Recurse -File |
    Where-Object {
        $_.Extension -in @('.ps1','.cmd') -and
        $_.FullName -notlike "*\tests\*" -and
        $_.FullName -notlike "*\.github\*"
    }
$runtimeText = ($runtimeFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"

Assert ($runtimeText -notmatch '(?i)\bStop-Process\b') 'Stop-Process call found.'
Assert ($runtimeText -notmatch '(?i)\btaskkill\b') 'taskkill call found.'
Assert ($runtimeText -notmatch '(?i)(chrome|msedge|browser)[\s\S]{0,160}(CloseMainWindow|Kill\(|taskkill|Stop-Process)') 'Browser closure targeting found.'
Assert ($runtimeText -notmatch '(?i)HaloInfinite[\s\S]{0,160}\.PriorityClass\s*=') 'HaloInfinite priority assignment found.'
Assert ($runtimeText -notmatch '(?i)\.PriorityClass\s*=') 'Process priority assignment found.'
Assert ($runtimeText -notmatch '(?i)(CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|SetWindowsHookEx)') 'Injection API found.'
Assert ($runtimeText -notmatch '(?i)(ReadProcessMemory|OpenProcess|PROCESS_VM_READ)') 'Game memory read API found.'
Assert ($runtimeText -notmatch '(?i)(SendInput|mouse_event|keybd_event)') 'Input manipulation API found.'

Write-Host '[OK] HaloSight smoke test passed.' -ForegroundColor Green
