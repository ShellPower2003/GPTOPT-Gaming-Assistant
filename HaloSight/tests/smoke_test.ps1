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

$defaultConfig = Get-Content -Raw -LiteralPath (Join-Path $Root 'config\halosight.default.json') | ConvertFrom-Json
Assert ($null -ne $defaultConfig.OptionalTools.NvidiaProfileInspectorPath) 'Default config missing NvidiaProfileInspectorPath.'

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
Assert (($launcherText -match 'Run-GPTOPT\.ps1"?\s+-Mode\s+gui') -or ($launcherText -match 'HaloSightGUI\.ps1')) 'GPTOPT_LAUNCHER.cmd must launch the GUI.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'
Assert ($launcherText -notmatch '(?i)HaloSight\.ps1"\s+-Mode\s+(start|stop|status|report)') 'GPTOPT_LAUNCHER.cmd exposes direct HaloSight modes.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match '\[ValidateSet\(''gui'',''test''\)\]') 'Run-GPTOPT.ps1 must only expose gui/test modes.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''gui''') 'Run-GPTOPT.ps1 must default to GUI mode.'
Assert ($runText -notmatch "(?i)'(start|stop|status|settings)'") 'Run-GPTOPT.ps1 exposes removed normal-user modes.'

$guiText = Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts\HaloSightGUI.ps1')
Assert ($guiText -match 'function Get-HaloSightDashboardState') 'Dashboard state function missing.'
Assert ($guiText -match 'function Get-GPTOPTNvidiaDisplayState') 'NVIDIA display state function missing.'
Assert ($guiText -match 'function Update-GPTOPTNvidiaDisplayPage') 'NVIDIA display page update function missing.'
Assert ($guiText -match 'function Update-HaloSightDashboardCards') 'Dashboard update function missing.'
Assert ($guiText -match 'function Update-HaloSightButtonStates') 'State-aware button function missing.'
Assert ($guiText -match 'function Invoke-HaloSightAsync') 'Async HaloSight helper missing.'
Assert ($guiText -match 'TabControl' -and $guiText -match 'Dashboard' -and $guiText -match 'HaloSight' -and $guiText -match 'NVIDIA / Display') 'Control Center tabs missing.'
Assert ($guiText -match 'Audio / Sonar' -and $guiText -match 'Controller / HID' -and $guiText -match 'Windows Gaming Health' -and $guiText -match 'Apps / Tools' -and $guiText -match 'Reports' -and $guiText -match 'Advanced / Revert') 'Control Center foundation pages missing.'
Assert ($guiText -match 'ReadyBtn') 'Ready for Halo button missing.'
Assert ($guiText -match 'RefreshBtn') 'Refresh Status button missing.'
Assert ($guiText -match 'Active Session' -and $guiText -match 'Latest Upload Zip' -and $guiText -match 'NVIDIA GPU' -and $guiText -match 'NVIDIA Driver' -and $guiText -match 'NVIDIA Profile Inspector') 'Required dashboard cards missing.'
Assert ($guiText -match 'NvidiaProfileInspectorPath') 'NVIDIA Profile Inspector config override missing from GUI.'
$nvidiaFunction = [regex]::Match($guiText, '(?s)function Get-GPTOPTNvidiaDisplayState \{(?<body>.*?)\n\}')
Assert $nvidiaFunction.Success 'NVIDIA detection function body missing.'
Assert ($nvidiaFunction.Groups['body'].Value -notmatch 'Start-Process|silentImport|\.nip|NvAPI|Set-ItemProperty|New-ItemProperty|reg\.exe|nvidiaProfileInspector\.exe\s+') 'NVIDIA detection must remain read-only.'
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
Assert ($runtimeText -notmatch '(?i)silentImport') 'NVIDIA Profile Inspector silentImport execution found.'
Assert ($runtimeText -notmatch '(?i)(Import|silentImport|Start-Process|&)[\s\S]{0,120}\.nip') 'NVIDIA .nip import behavior found.'
Assert ($runtimeText -notmatch '(?i)(NvAPI|DRS_Set|DRS_Save|nvidiaProfileInspector\.exe\s+.*-(silent|import))') 'Direct NVIDIA profile write behavior found.'
Assert ($runtimeText -notmatch '(?i)(chrome|msedge|browser)[\s\S]{0,160}(CloseMainWindow|Kill\(|taskkill|Stop-Process)') 'Browser closure targeting found.'
Assert ($runtimeText -notmatch '(?i)HaloInfinite[\s\S]{0,160}\.PriorityClass\s*=') 'HaloInfinite priority assignment found.'
Assert ($runtimeText -notmatch '(?i)\.PriorityClass\s*=') 'Process priority assignment found.'
Assert ($runtimeText -notmatch '(?i)(CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|SetWindowsHookEx)') 'Injection API found.'
Assert ($runtimeText -notmatch '(?i)(ReadProcessMemory|OpenProcess|PROCESS_VM_READ)') 'Game memory read API found.'
Assert ($runtimeText -notmatch '(?i)(SendInput|mouse_event|keybd_event)') 'Input manipulation API found.'
Assert ($runtimeText -notmatch '(?i)(Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe)') 'Automatic reboot/logoff/shutdown behavior found.'

Write-Host '[OK] HaloSight smoke test passed.' -ForegroundColor Green
