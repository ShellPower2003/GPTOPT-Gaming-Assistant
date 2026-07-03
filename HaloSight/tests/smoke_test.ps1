param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$SettingsScript = Join-Path $Root 'scripts\HaloSightSettings.ps1'
$UserConfigPath = Join-Path $Root 'config\halosight.user.json'
$RepoRoot = Split-Path -Parent $Root
$LauncherPath = Join-Path $Root 'GPTOPT_LAUNCHER.cmd'
if(!(Test-Path -LiteralPath $LauncherPath)){ $LauncherPath = Join-Path $RepoRoot 'GPTOPT_LAUNCHER.cmd' }
$RunGptOptPath = Join-Path $Root 'Run-GPTOPT.ps1'
if(!(Test-Path -LiteralPath $RunGptOptPath)){ $RunGptOptPath = Join-Path $RepoRoot 'Run-GPTOPT.ps1' }
$GuidedControlPath = Join-Path $RepoRoot 'Scripts\Invoke-GPTOPTGuidedControlCenter.ps1'
$AdvancedControlPath = Join-Path $RepoRoot 'Scripts\Invoke-GPTOPTControlCenter.ps1'
$BootstrapPath = Join-Path $RepoRoot 'gptopt.ps1'
$SafetyPath = Join-Path $RepoRoot 'Scripts\Test-GPTOPTSafety.ps1'
$CheckExplanationsPath = Join-Path $RepoRoot 'Knowledge\check-explanations.json'

function Assert($Condition, $Message){
    if(-not $Condition){ throw $Message }
}

function Assert-Parses($Path){
    $code = Get-Content -Raw -LiteralPath $Path
    $null = [scriptblock]::Create($code)
}

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1' |
    ForEach-Object { Assert-Parses $_.FullName }

foreach($path in @($RunGptOptPath,$GuidedControlPath,$AdvancedControlPath,$BootstrapPath,$SafetyPath)){
    Assert (Test-Path -LiteralPath $path) "$path missing."
    Assert-Parses $path
}

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
Assert ($launcherText -match 'Run-GPTOPT\.ps1"?\s+-Mode\s+guided') 'GPTOPT_LAUNCHER.cmd must launch Guided Mode first.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'
Assert ($launcherText -notmatch '(?i)HaloSight\.ps1"\s+-Mode\s+(start|stop|status|report)') 'GPTOPT_LAUNCHER.cmd exposes direct HaloSight modes.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match "'guided'" -and $runText -match "'gui'" -and $runText -match "'advanced'" -and $runText -match "'test'" -and $runText -match "'safety'" -and $runText -match "'recommend'" -and $runText -match "'queue'" -and $runText -match "'report'") 'Run-GPTOPT.ps1 must expose the app router modes.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''guided''') 'Run-GPTOPT.ps1 must default to Guided Mode.'
Assert ($runText -match 'Invoke-GPTOPTGuidedControlCenter\.ps1') 'Run-GPTOPT.ps1 guided/gui modes must launch the Guided Control Center first.'
Assert ($runText -match 'Invoke-GPTOPTControlCenter\.ps1' -and $runText -match 'Invoke-GPTOPTAppGUI\.ps1') 'Run-GPTOPT.ps1 must keep Advanced Control Center fallback available.'
Assert ($runText -notmatch '(?i)HaloSight\.ps1[\s\S]{0,160}-Mode\s+(start|stop|status|settings)') 'Run-GPTOPT.ps1 exposes direct HaloSight normal-user modes.'
Assert ($runText -match 'Test-GPTOPTSafety\.ps1') 'Run-GPTOPT.ps1 must route to the safety scanner.'
Assert ($runText -match 'New-GPTOPTPreviewQueue') 'Run-GPTOPT.ps1 must build a preview queue.'
Assert ($runText -match 'New-GPTOPTReport') 'Run-GPTOPT.ps1 must generate reports.'

$guidedText = Get-Content -Raw -LiteralPath $GuidedControlPath
Assert ($guidedText -match 'Ready to Play' -and $guidedText -match 'Ready with Review Items' -and $guidedText -match 'Fix First') 'Guided Control Center must show readiness cards.'
Assert ($guidedText -match 'Game Profile' -and $guidedText -match 'Get-GuidedProfiles') 'Guided Control Center must include a profile selector.'
Assert ($guidedText -match 'halo\.infinite' -and $guidedText -match 'generic\.shooter') 'Guided Control Center must support Halo without being Halo-only.'
Assert ($guidedText -match 'Show Details' -and $guidedText -match 'DetailsBox.Visibility = ''Collapsed''') 'Guided Control Center must hide technical details by default.'
Assert ($guidedText -match 'check-explanations\.json' -and $guidedText -match 'Get-CardExplanation') 'Guided Mode must load the check explanation model.'
Assert ($guidedText -match 'Current status:' -and $guidedText -match 'Summary:' -and $guidedText -match 'Why it matters:' -and $guidedText -match 'Good state:' -and $guidedText -match 'Safe action:' -and $guidedText -match 'Risk:' -and $guidedText -match 'Undo path:') 'Every readiness card must render the required explanation fields.'
Assert ($guidedText -notmatch '(?s)\$cardLines.*?\$card\.Details') 'Raw card evidence must not be rendered in readiness cards.'
Assert (Test-Path -LiteralPath $CheckExplanationsPath) 'Knowledge/check-explanations.json missing.'
$checkExplanations = Get-Content -Raw -LiteralPath $CheckExplanationsPath | ConvertFrom-Json
$requiredAreas = @('Windows Reboot State','Windows Gaming Settings','RTSS FPS Cap','FPS Limiter','Halo Display Settings','Audio Routing','Optional Session Tools')
foreach($area in $requiredAreas){
    $entry = $checkExplanations.guidedCards.PSObject.Properties[$area].Value
    Assert ($null -ne $entry -and $entry.label -and $entry.whyItMatters -and $entry.goodState) "Missing Guided explanation for $area."
}
Assert ($guidedText -match 'Recommended Action Queue' -and $guidedText -match 'WhatItChanges' -and $guidedText -match 'BackupUndoPath' -and $guidedText -match 'RequiresReboot') 'Guided queue must explain changes, backup/undo, and reboot.'
Assert ($guidedText -match 'Pre-Game Routine' -and $guidedText -match 'Initialize-Routine' -and $guidedText -match 'RoutineProgressText') 'Guided Control Center must include an interactive pre-game routine.'
Assert ($guidedText -match 'Session Focus' -and $guidedText -match 'Get-CurrentRoutineState' -and $guidedText -match '## Pre-Game Routine') 'Guided reports must capture routine completion and session focus.'
Assert ($guidedText -match 'ApplicationDetectionLevel\\s\*=\\s\*2' -and $guidedText -match 'Get-SonarState') 'Guided readiness must require RTSS detection level 2 and use Sonar device fallback.'
Assert ($guidedText -match 'Classification=Cleanup' -and $guidedText -match 'Classification=Servicing') 'Guided readiness must distinguish cleanup-only and servicing reboot states.'
Assert ($guidedText -notmatch '(?i)Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|reg\.exe\s+add|reg\.exe\s+delete|Restart-Computer|shutdown\.exe') 'Guided Control Center must not apply risky settings.'

$bootstrapText = Get-Content -Raw -LiteralPath $BootstrapPath
Assert ($bootstrapText -notmatch 'Set-Content\s+-Path\s+\$Run' -and $bootstrapText -notmatch 'Set-Content\s+-LiteralPath\s+\$Run') 'Bootstrap must not overwrite the tracked Run-GPTOPT.ps1 router.'
Assert ($bootstrapText -match 'GPTOPT-LaunchFallback\.ps1') 'Bootstrap must use a separate fallback launcher when the tracked router is missing.'

$safetyText = Get-Content -Raw -LiteralPath $SafetyPath
Assert ($safetyText -match 'root\\Microsoft\\Windows\\DeviceGuard') 'Safety scan must query Win32_DeviceGuard from the DeviceGuard namespace.'
Assert ($safetyText -match 'CBS PackagesPending' -and $safetyText -match 'Classification = ''Cleanup''' -and $safetyText -match 'Classification = ''Servicing''') 'Safety scan must split servicing and cleanup-only reboot states.'

$guiText = Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts\HaloSightGUI.ps1')
Assert ($guiText -match 'function Get-HaloSightDashboardState') 'Dashboard state function missing.'
Assert ($guiText -match 'function Update-HaloSightDashboardCards') 'Dashboard update function missing.'
Assert ($guiText -match 'function Update-HaloSightButtonStates') 'State-aware button function missing.'
Assert ($guiText -match 'function Invoke-HaloSightAsync') 'Async HaloSight helper missing.'
Assert ($guiText -match 'ReadyBtn') 'Ready for Halo button missing.'
Assert ($guiText -match 'RefreshBtn') 'Refresh Status button missing.'
Assert ($guiText -match 'Active Session' -and $guiText -match 'Latest Upload Zip') 'Required dashboard cards missing.'
$readyHandler = [regex]::Match($guiText, '(?s)\$window\.FindName\("ReadyBtn"\)\.Add_Click\(\{(?<body>.*?)\}\)')
Assert $readyHandler.Success 'Ready for Halo handler missing.'
Assert ($readyHandler.Groups['body'].Value -match 'Update-HaloSightDashboardCards') 'Ready for Halo must update dashboard cards.'
Assert ($readyHandler.Groups['body'].Value -notmatch 'Run-HS|Start-Process|Save-HaloSightConfig|Reset-HaloSightConfig|HaloSight\.ps1') 'Ready for Halo must remain read-only.'
foreach($button in @('StartBtn','StopBtn','StatusBtn','ReportBtn')){
    $handler = [regex]::Match($guiText, "(?s)\`$window\.FindName\(\`"$button\`"\)\.Add_Click\(\{(?<body>.*?)\}\)")
    Assert $handler.Success "$button handler missing."
    Assert ($handler.Groups['body'].Value -match 'Invoke-HaloSightAsync') "$button must use async helper."
    Assert ($handler.Groups['body'].Value -notmatch 'WaitForExit|ReadToEnd|Run-HS') "$button handler must not block the WPF thread."
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
Assert ($runtimeText -notmatch '(?i)(Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe)') 'Automatic reboot/logoff/shutdown behavior found.'

Write-Host '[OK] HaloSight smoke test passed.' -ForegroundColor Green
