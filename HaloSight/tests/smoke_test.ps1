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
$AuditScriptPath = Join-Path $RepoRoot 'Scripts\Invoke-GPTOPTAudit.ps1'
$DiagnosticsPath = Join-Path $RepoRoot 'src\GPTOPT.App\Services\DiagnosticsService.cs'
$RecommendationPath = Join-Path $RepoRoot 'src\GPTOPT.App\Services\RecommendationService.cs'
$ProjectPath = Join-Path $RepoRoot 'src\GPTOPT.App\GPTOPT.App.csproj'
$XamlPath = Join-Path $RepoRoot 'src\GPTOPT.App\MainWindow.xaml'

function Assert($Condition, $Message){ if(-not $Condition){ throw $Message } }
function Assert-Parses($Path){ $null = [scriptblock]::Create((Get-Content -Raw -LiteralPath $Path)) }

Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1' | ForEach-Object { Assert-Parses $_.FullName }
Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.json' | ForEach-Object { $null = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json }
Assert-Parses $RunGptOptPath
Assert-Parses $BuildPath
Assert-Parses $AuditScriptPath

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
    if($null -ne $configBackup){ $configBackup | Out-File -FilePath $UserConfigPath -Encoding UTF8 }
    else{ Remove-Item -LiteralPath $UserConfigPath -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
}

foreach($requiredPath in @($LauncherPath,$RunGptOptPath,$BuildPath,$AuditScriptPath,$DiagnosticsPath,$RecommendationPath,$ProjectPath,$XamlPath)){
    Assert (Test-Path -LiteralPath $requiredPath) "Required runtime file missing: $requiredPath"
}

$launcherText = Get-Content -Raw -LiteralPath $LauncherPath
Assert ($launcherText -match 'Run-GPTOPT\.ps1"?\s+-Mode\s+gui') 'GPTOPT_LAUNCHER.cmd must launch Run-GPTOPT.ps1 in native GUI mode.'
Assert ($launcherText -notmatch '(?i):menu|set /p|Select an option|HaloSight Start|HaloSight Stop|HaloSight Status|HaloSight Settings|Run Smoke Test') 'GPTOPT_LAUNCHER.cmd contains old menu workflow.'

$runText = Get-Content -Raw -LiteralPath $RunGptOptPath
Assert ($runText -match '\[ValidateSet\(''gui'',''legacy'',''test'',''rebuild''\)\]') 'Run-GPTOPT.ps1 mode contract mismatch.'
Assert ($runText -match '\[string\]\$Mode\s*=\s*''gui''') 'Run-GPTOPT.ps1 must default to GUI mode.'
Assert ($runText -match 'Start-NativeApp') 'Run-GPTOPT.ps1 must launch the native app.'
Assert ($runText -match 'agent/native-desktop-app') 'Run-GPTOPT.ps1 must update from the native-app branch.'
Assert ($runText -match '\.gptopt-build-commit') 'Run-GPTOPT.ps1 must use a commit-based build stamp.'

$buildText = Get-Content -Raw -LiteralPath $BuildPath
Assert ($buildText -match 'dotnet\.Source build') 'Native build command missing.'
Assert ($buildText -match 'dotnet\.Source publish') 'Native publish command missing.'
Assert ($buildText -notmatch 'Set-Content\s+-LiteralPath\s+\$Xaml') 'Build script must not rewrite tracked XAML.'

$auditText = Get-Content -Raw -LiteralPath $AuditScriptPath
Assert ($auditText -match 'collector_version=''0\.4\.1''') 'Audit collector version must be 0.4.1.'
Assert ($auditText -match 'function Get-ControllerEventSummary') 'Controller-specific event classification is missing.'
Assert ($auditText -match 'controller_fault_evidence') 'Controller evidence must be persisted and published.'
Assert ($auditText -notmatch '\$controllerFaults=Get-EventCount') 'Broad controller provider counting regression detected.'

$diagnosticsText = Get-Content -Raw -LiteralPath $DiagnosticsPath
Assert ($diagnosticsText -match 'DECISION') 'Targeted diagnostics must lead with a decision.'
Assert ($diagnosticsText -match 'BLOCKING FINDINGS') 'Targeted diagnostics must classify blocking findings.'
Assert ($diagnosticsText -match 'REVIEW FINDINGS') 'Targeted diagnostics must classify review findings.'
Assert ($diagnosticsText -match 'EVIDENCE — CONTROLLER EVENTS') 'Targeted diagnostics must expose controller evidence.'
Assert ($diagnosticsText -match 'VID_045E&PID_028E') 'Targeted diagnostics must recognize the Vader controller hardware path.'

$recommendationText = Get-Content -Raw -LiteralPath $RecommendationPath
foreach($requiredFinding in @('Hardware instability requires investigation','GPU/display reset evidence','Storage timeout or fault evidence','Confirmed controller-path events','Gaming-related process crashes','Background crashes retained for context')){
    Assert ($recommendationText -match [regex]::Escape($requiredFinding)) "Evidence-specific recommendation missing: $requiredFinding"
}
Assert ($recommendationText -notmatch 'Title = "Classify recent Windows errors"') 'Generic raw-error recommendation regression detected.'
Assert ($recommendationText -match 'gamingservicesproxy_11\.dll\.0') 'Stale Gaming Services entry must be classified separately.'

[xml](Get-Content -Raw -LiteralPath $XamlPath) | Out-Null
$xamlText = Get-Content -Raw -LiteralPath $XamlPath
foreach($requiredHandler in @('PrepareForHalo_Click','RunTargetedDiagnostics_Click','AnalyzeLatestSession_Click','CompareCaptures_Click','OpenPresentMonRobust_Click','PublishAuditButton_Click','OpenRollbackManager_Click')){
    Assert ($xamlText -match ('Click="' + [regex]::Escape($requiredHandler) + '"')) "Required native handler $requiredHandler is not wired in XAML."
}

$runtimePaths = @($LauncherPath,$RunGptOptPath,$BuildPath,$AuditScriptPath) + @(Get-ChildItem -LiteralPath (Join-Path $Root 'scripts') -Recurse -File -Include '*.ps1','*.cmd' | Select-Object -ExpandProperty FullName)
$runtimeText = ($runtimePaths | Sort-Object -Unique | ForEach-Object { Get-Content -Raw -LiteralPath $_ }) -join "`n"
Assert ($runtimeText -notmatch '(?i)\btaskkill\b') 'taskkill call found in shipped runtime.'
Assert ($runtimeText -notmatch '(?i)\.PriorityClass\s*=') 'Process priority assignment found.'
Assert ($runtimeText -notmatch '(?i)(CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|SetWindowsHookEx|ReadProcessMemory|OpenProcess|PROCESS_VM_READ)') 'Process injection or memory access API found.'
Assert ($runtimeText -notmatch '(?i)(SendInput|mouse_event|keybd_event)') 'Input manipulation API found.'
Assert ($runtimeText -notmatch '(?i)(Restart-Computer|Stop-Computer|shutdown\.exe|logoff\.exe)') 'Automatic reboot/logoff/shutdown behavior found.'

Write-Host '[OK] GPTOPT native and HaloSight smoke tests passed.' -ForegroundColor Green