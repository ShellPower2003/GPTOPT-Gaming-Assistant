param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$CoreScript = Join-Path $Root 'scripts\HaloSight.ps1'
$SettingsScript = Join-Path $Root 'scripts\HaloSightSettings.ps1'
$AuditScript = Join-Path $Root 'scripts\GPTOPTAudit.ps1'
$ActualUserConfigPath = Join-Path $Root 'config\halosight.user.json'
$RepoRoot = Split-Path -Parent $Root
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

$oldUserProfile = $env:USERPROFILE
$oldUserConfigPath = $env:HALOSIGHT_USER_CONFIG_PATH
$testHome = Join-Path $env:TEMP ("HaloSightSmoke_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testHome | Out-Null
$env:HALOSIGHT_USER_CONFIG_PATH = Join-Path $testHome 'config\halosight.user.json'
$actualUserConfigBefore = if(Test-Path -LiteralPath $ActualUserConfigPath){ Get-Content -Raw -LiteralPath $ActualUserConfigPath }else{ $null }

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.json' |
    ForEach-Object { $null = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json }

. $SettingsScript

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
    if($null -eq $oldUserConfigPath){
        Remove-Item Env:\HALOSIGHT_USER_CONFIG_PATH -ErrorAction SilentlyContinue
    }else{
        $env:HALOSIGHT_USER_CONFIG_PATH = $oldUserConfigPath
    }
    Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
}

$actualUserConfigAfter = if(Test-Path -LiteralPath $ActualUserConfigPath){ Get-Content -Raw -LiteralPath $ActualUserConfigPath }else{ $null }
Assert ($actualUserConfigBefore -eq $actualUserConfigAfter) 'Smoke test modified HaloSight/config/halosight.user.json.'

$launcherText = Get-Content -Raw -LiteralPath $LauncherPath
Assert (($launcherText -match 'Run-GPTOPT\.ps1"?\s+-Mode\s+gui') -or ($launcherText -match 'HaloSightGUI\.ps1')) 'GPTOPT_LAUNCHER.cmd must launch the GUI-first path.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'
Assert ($launcherText -notmatch '(?i)HaloSight\.ps1"\s+-Mode\s+(start|stop|status|report)') 'GPTOPT_LAUNCHER.cmd exposes direct HaloSight modes.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match '\[ValidateSet\(''gui'',''legacy'',''test''\)\]') 'Run-GPTOPT.ps1 must expose gui/legacy/test modes.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''gui''') 'Run-GPTOPT.ps1 must default to GUI mode.'
Assert ($runText -match 'Invoke-GPTOPTDesktopApp\.ps1') 'Run-GPTOPT.ps1 gui mode must launch the GPTOPT desktop app.'
Assert ($runText -match 'HaloSightGUI\.ps1') 'Run-GPTOPT.ps1 legacy mode must retain the HaloSight GUI fallback.'
Assert ($runText -notmatch "(?im)^\s*'(start|stop|status|settings)'\s*\{") 'Run-GPTOPT.ps1 exposes removed normal-user switch modes.'

$guiText = Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts\HaloSightGUI.ps1')
$auditText = Get-Content -Raw -LiteralPath $AuditScript
Assert ($guiText -match 'function Get-HaloSightDashboardState') 'Dashboard state function missing.'
Assert ($guiText -match 'function Update-HaloSightDashboardCards') 'Dashboard update function missing.'
Assert ($guiText -match 'function Update-HaloSightButtonStates') 'State-aware button function missing.'
Assert ($guiText -match 'function Invoke-HaloSightAsync') 'Async HaloSight helper missing.'
Assert ($guiText -match 'ControlCenterTabs') 'Control Center tab control missing.'
foreach($tabLabel in @('Audio / Sonar','Controller / HID','Windows Gaming Health','Apps / Tools','Reports','Advanced / Revert')){
    Assert ($guiText -match [regex]::Escape($tabLabel)) "Functional tab missing: $tabLabel"
}
Assert ($guiText -notmatch '(?i)coming soon|placeholder|not implemented|todo') 'Placeholder text remains in GUI functional tabs.'
foreach($fn in @('Get-GPTOPTAudioSonarAudit','Get-GPTOPTControllerHidAudit','Get-GPTOPTWindowsGamingHealthAudit','Get-GPTOPTAppsToolsAudit','Get-GPTOPTReportsAudit','Get-GPTOPTAdvancedRevertAudit')){
    Assert ($auditText -match "function\s+$fn") "Backend audit function missing: $fn"
    Assert ($guiText -match $fn) "GUI does not call backend audit function: $fn"
}
. $AuditScript
$auditOutputs = @(
    (Get-GPTOPTAudioSonarAudit),
    (Get-GPTOPTControllerHidAudit),
    (Get-GPTOPTWindowsGamingHealthAudit),
    (Get-GPTOPTAppsToolsAudit),
    (Get-GPTOPTReportsAudit -SessionRoot $testHome),
    (Get-GPTOPTAdvancedRevertAudit -RepoRoot $RepoRoot)
)
foreach($auditOutput in $auditOutputs){
    Assert ($auditOutput -match 'Generated:') 'Audit output is missing generated timestamp.'
    Assert ($auditOutput -match 'Scope: read-only audit') 'Audit output is missing read-only scope marker.'
    Assert ($auditOutput -match '\[(GOOD|WARN|BAD|UNKNOWN|INFO)\]') 'Audit output is missing status rows.'
}
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
foreach($button in @('RefreshAudioAuditBtn','RefreshControllerAuditBtn','RefreshWindowsAuditBtn','RefreshAppsAuditBtn','RefreshReportsAuditBtn','RefreshAdvancedAuditBtn')){
    $handler = [regex]::Match($guiText, "(?s)\`$window\.FindName\(\`"$button\`"\)\.Add_Click\(\{(?<body>.*?)\}\)")
    Assert $handler.Success "$button handler missing."
    Assert ($handler.Groups['body'].Value -match 'Set-GPTOPTAuditTabText') "$button must use audit tab helper."
    Assert ($handler.Groups['body'].Value -notmatch '(?i)\b(Set-Item|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|New-Item|Remove-Item|Copy-Item|Move-Item|Rename-Item|Set-Service|Stop-Service|Start-Service|Restart-Service|powercfg\s+/(set|change)|reg\.exe\s+(add|delete|import)|pnputil|devcon|bcdedit|Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe|Stop-Process|taskkill)\b') "$button handler contains direct mutation command."
}
$handlerMatches = [regex]::Matches($guiText, '(?s)\.Add_Click\(\{(?<body>.*?)\}\)')
foreach($handlerMatch in $handlerMatches){
    Assert ($handlerMatch.Groups['body'].Value -notmatch '(?i)\b(Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|Start-Service|Restart-Service|powercfg\s+/(set|change|setactive)|reg\.exe\s+(add|delete|import)|pnputil|devcon|bcdedit|Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe|Stop-Process|taskkill|Set-MpPreference|Add-MpPreference|Remove-MpPreference|nvidiaProfileInspector\.exe\s+-silentImport)\b') 'GUI click handler contains direct Windows-state mutation command.'
}

Assert ($guiText -notmatch '(?i)windows11-scripts') 'GUI imports windows11-scripts.'
Assert ($auditText -notmatch '(?i)windows11-scripts') 'Audit backend imports windows11-scripts.'

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
