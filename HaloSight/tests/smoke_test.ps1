param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$SettingsScript = Join-Path $Root 'scripts\HaloSightSettings.ps1'
$UserConfigPath = Join-Path $Root 'config\halosight.user.json'
$RepoRoot = Split-Path -Parent $Root
$LauncherPath = Join-Path $RepoRoot 'GPTOPT_LAUNCHER.cmd'
$RunGptOptPath = Join-Path $RepoRoot 'Run-GPTOPT.ps1'
$BuildPath = Join-Path $RepoRoot 'Build-GPTOPTApp.ps1'
$ProjectPath = Join-Path $RepoRoot 'src\GPTOPT.App\GPTOPT.App.csproj'
$XamlPath = Join-Path $RepoRoot 'src\GPTOPT.App\MainWindow.xaml'

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

Assert (Test-Path -LiteralPath $LauncherPath) 'GPTOPT_LAUNCHER.cmd missing.'
Assert (Test-Path -LiteralPath $RunGptOptPath) 'Run-GPTOPT.ps1 missing.'
Assert (Test-Path -LiteralPath $BuildPath) 'Build-GPTOPTApp.ps1 missing.'
Assert (Test-Path -LiteralPath $ProjectPath) 'Native app project missing.'
Assert (Test-Path -LiteralPath $XamlPath) 'Native app XAML missing.'

$launcherText = Get-Content -Raw -LiteralPath $LauncherPath
Assert ($launcherText -match 'Run-GPTOPT\.ps1"?\s+-Mode\s+gui') 'GPTOPT_LAUNCHER.cmd must launch Run-GPTOPT.ps1 in native GUI mode.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'
Assert ($launcherText -notmatch '(?i)HaloSight\.ps1"\s+-Mode\s+(start|stop|status|report)') 'GPTOPT_LAUNCHER.cmd exposes direct HaloSight modes.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match '\[ValidateSet\(''gui'',''legacy'',''test'',''rebuild''\)\]') 'Run-GPTOPT.ps1 mode contract mismatch.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''gui''') 'Run-GPTOPT.ps1 must default to GUI mode.'
Assert ($runText -match 'Start-NativeApp') 'Run-GPTOPT.ps1 must launch the native app.'
Assert ($runText -match 'Build-GPTOPTApp\.ps1') 'Run-GPTOPT.ps1 must invoke the native build path when required.'
Assert ($runText -match 'agent/native-desktop-app') 'Run-GPTOPT.ps1 must update from the native-app branch.'
Assert ($runText -match '\.gptopt-build-commit') 'Run-GPTOPT.ps1 must use a commit-based build stamp.'
Assert ($runText -notmatch '(?i)''(start|stop|status|settings)''\s*\{') 'Run-GPTOPT.ps1 exposes removed normal-user modes.'

$buildText = Get-Content -Raw -LiteralPath $BuildPath
Assert ($buildText -match 'dotnet\.Source build') 'Native build command missing.'
Assert ($buildText -match 'dotnet\.Source publish') 'Native publish command missing.'
Assert ($buildText -notmatch 'Set-Content\s+-LiteralPath\s+\$Xaml') 'Build script must not rewrite tracked XAML.'

[xml](Get-Content -Raw -LiteralPath $XamlPath) | Out-Null
$xamlText = Get-Content -Raw -LiteralPath $XamlPath
foreach($requiredHandler in @(
    'PrepareForHalo_Click',
    'RunTargetedDiagnostics_Click',
    'AnalyzeLatestSession_Click',
    'CompareCaptures_Click',
    'OpenPresentMonRobust_Click',
    'PublishAuditButton_Click',
    'OpenRollbackManager_Click'
)){
    Assert ($xamlText -match ('Click="' + [regex]::Escape($requiredHandler) + '"')) "Required native handler $requiredHandler is not wired in XAML."
}

$runtimeFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
    Where-Object {
        $_.Extension -in @('.ps1','.cmd') -and
        $_.FullName -notlike "*\tests\*" -and
        $_.FullName -notlike "*\.github\*" -and
        $_.FullName -notlike "*\bin\*" -and
        $_.FullName -notlike "*\obj\*" -and
        $_.FullName -notlike "*\dist\*"
    }
$runtimeText = ($runtimeFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"

Assert ($runtimeText -notmatch '(?i)\btaskkill\b') 'taskkill call found.'
Assert ($runtimeText -notmatch '(?i)(chrome|msedge|browser)[\s\S]{0,160}(CloseMainWindow|Kill\(|taskkill|Stop-Process)') 'Browser closure targeting found.'
Assert ($runtimeText -notmatch '(?i)HaloInfinite[\s\S]{0,160}\.PriorityClass\s*=') 'HaloInfinite priority assignment found.'
Assert ($runtimeText -notmatch '(?i)\.PriorityClass\s*=') 'Process priority assignment found.'
Assert ($runtimeText -notmatch '(?i)(CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|SetWindowsHookEx)') 'Injection API found.'
Assert ($runtimeText -notmatch '(?i)(ReadProcessMemory|OpenProcess|PROCESS_VM_READ)') 'Game memory read API found.'
Assert ($runtimeText -notmatch '(?i)(SendInput|mouse_event|keybd_event)') 'Input manipulation API found.'
Assert ($runtimeText -notmatch '(?i)(Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe)') 'Automatic reboot/logoff/shutdown behavior found.'

Write-Host '[OK] GPTOPT native and HaloSight smoke tests passed.' -ForegroundColor Green
