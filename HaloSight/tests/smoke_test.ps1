param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $Root
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$SettingsScript = Join-Path $Root 'scripts\HaloSightSettings.ps1'
$UserConfigPath = Join-Path $Root 'config\halosight.user.json'
$LauncherPath = Join-Path $Root 'GPTOPT_LAUNCHER.cmd'
if(!(Test-Path -LiteralPath $LauncherPath)){ $LauncherPath = Join-Path $RepoRoot 'GPTOPT_LAUNCHER.cmd' }
$RunGptOptPath = Join-Path $Root 'Run-GPTOPT.ps1'
if(!(Test-Path -LiteralPath $RunGptOptPath)){ $RunGptOptPath = Join-Path $RepoRoot 'Run-GPTOPT.ps1' }

function Assert($Condition, $Message){
    if(-not $Condition){ throw $Message }
}

function Assert-Parses($Path){
    $code = Get-Content -Raw -LiteralPath $Path
    $null = [scriptblock]::Create($code)
}

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1' |
    ForEach-Object { Assert-Parses $_.FullName }
Assert-Parses $RunGptOptPath

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

$launcherText = Get-Content -Raw -LiteralPath $LauncherPath
Assert ($launcherText -match 'Run-GPTOPT\.ps1|HaloSightGUI\.ps1') 'GPTOPT_LAUNCHER.cmd must launch the GUI path.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'
Assert ($launcherText -notmatch '(?i)HaloSight\.ps1"\s+-Mode\s+(start|stop|status|report)') 'GPTOPT_LAUNCHER.cmd exposes direct HaloSight modes.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match '\[ValidateSet\(''gui'',''test''\)\]') 'Run-GPTOPT.ps1 must only expose gui/test modes.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''gui''') 'Run-GPTOPT.ps1 must default to GUI mode.'
Assert ($runText -notmatch "(?i)'(start|stop|status|settings)'") 'Run-GPTOPT.ps1 exposes removed normal-user modes.'

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
Assert ($runtimeText -notmatch '(?i)(Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe)') 'Automatic reboot/logoff/shutdown behavior found.'

Write-Host '[OK] HaloSight smoke test passed.' -ForegroundColor Green
