function ConvertTo-GPTOPTAuditLine {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$State,
        [string]$Detail = ''
    )
    [pscustomobject]@{
        Name = $Name
        State = $State
        Detail = $Detail
    }
}

function Format-GPTOPTAuditRows {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)]$Rows
    )
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($Title)
    $lines.Add(('=' * $Title.Length))
    $lines.Add("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
    $lines.Add('Scope: read-only audit. No settings are changed.')
    $lines.Add('')
    foreach($row in @($Rows)){
        $detail = if([string]::IsNullOrWhiteSpace($row.Detail)){ '' }else{ " - $($row.Detail)" }
        $lines.Add(("[{0}] {1}{2}" -f $row.State, $row.Name, $detail))
    }
    return ($lines -join "`r`n")
}

function Get-GPTOPTProcessSummary {
    param([string[]]$Names)
    $found = @(Get-Process $Names -ErrorAction SilentlyContinue)
    if($found.Count -eq 0){ return 'Not detected' }
    return (($found | Select-Object -ExpandProperty ProcessName -Unique) -join ', ')
}

function Get-GPTOPTServiceSummary {
    param([string[]]$Names)
    $services = @(Get-Service $Names -ErrorAction SilentlyContinue)
    if($services.Count -eq 0){ return 'Not found' }
    return (($services | ForEach-Object { "$($_.Name)=$($_.Status)" }) -join ', ')
}

function Get-GPTOPTRegistryValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name
    )
    try{
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }catch{
        return $null
    }
}

function Get-GPTOPTAudioSonarAudit {
    $sound = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue)
    $audioServices = Get-GPTOPTServiceSummary @('Audiosrv','AudioEndpointBuilder')
    $sonar = Get-GPTOPTProcessSummary @('SteelSeriesSonar','SteelSeriesEngine','SteelSeriesGG','audiodg')
    $problemAudio = @($sound | Where-Object { $_.Status -and $_.Status -ne 'OK' })
    $rows = @(
        (ConvertTo-GPTOPTAuditLine 'Windows audio services' ($(if($audioServices -match '=Running'){ 'GOOD' }else{ 'WARN' })) $audioServices)
        (ConvertTo-GPTOPTAuditLine 'SteelSeries Sonar / audio engine processes' ($(if($sonar -ne 'Not detected'){ 'GOOD' }else{ 'UNKNOWN' })) $sonar)
        (ConvertTo-GPTOPTAuditLine 'Sound devices visible to WMI' ($(if($sound.Count -gt 0){ 'GOOD' }else{ 'WARN' })) "$($sound.Count) device(s)")
        (ConvertTo-GPTOPTAuditLine 'Sound devices reporting problems' ($(if($problemAudio.Count -eq 0){ 'GOOD' }else{ 'WARN' })) "$($problemAudio.Count) issue(s)")
    )
    return Format-GPTOPTAuditRows 'Audio / Sonar Audit' $rows
}

function Get-GPTOPTControllerHidAudit {
    $hid = @(Get-PnpDevice -Class HIDClass -ErrorAction SilentlyContinue)
    $usb = @(Get-PnpDevice -Class USB -ErrorAction SilentlyContinue)
    $game = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Class -in @('HIDClass','USB','XnaComposite') -and $_.FriendlyName -match 'controller|gamepad|xbox|flydigi|dualsense|dualshock|hid' })
    $problems = @($hid + $usb | Where-Object { $_.Status -notin @('OK','Unknown') })
    $rows = @(
        (ConvertTo-GPTOPTAuditLine 'HID devices' ($(if($hid.Count -gt 0){ 'GOOD' }else{ 'UNKNOWN' })) "$($hid.Count) detected")
        (ConvertTo-GPTOPTAuditLine 'USB devices' ($(if($usb.Count -gt 0){ 'GOOD' }else{ 'UNKNOWN' })) "$($usb.Count) detected")
        (ConvertTo-GPTOPTAuditLine 'Controller-like devices' ($(if($game.Count -gt 0){ 'GOOD' }else{ 'UNKNOWN' })) "$($game.Count) detected")
        (ConvertTo-GPTOPTAuditLine 'HID/USB problem devices' ($(if($problems.Count -eq 0){ 'GOOD' }else{ 'WARN' })) "$($problems.Count) issue(s)")
        (ConvertTo-GPTOPTAuditLine 'GameInput service' ($(if((Get-GPTOPTServiceSummary @('GameInputSvc')) -match '=Running'){ 'GOOD' }else{ 'WARN' })) (Get-GPTOPTServiceSummary @('GameInputSvc')))
    )
    return Format-GPTOPTAuditRows 'Controller / HID Audit' $rows
}

function Get-GPTOPTWindowsGamingHealthAudit {
    $gameDvrEnabled = Get-GPTOPTRegistryValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
    $appCaptureEnabled = Get-GPTOPTRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
    $hags = Get-GPTOPTRegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    $mpo = Get-GPTOPTRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
    $activePlan = try { ((powercfg /getactivescheme) -join ' ') } catch { 'Unavailable' }
    $cbsPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $wuPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $gamingServices = Get-GPTOPTServiceSummary @('GamingServices','GamingServicesNet','XblAuthManager','XboxGipSvc','GameInputSvc')
    $rows = @(
        (ConvertTo-GPTOPTAuditLine 'Active power plan' 'INFO' $activePlan)
        (ConvertTo-GPTOPTAuditLine 'HAGS registry value' 'INFO' ($(if($null -eq $hags){ 'Not set' }else{ [string]$hags })))
        (ConvertTo-GPTOPTAuditLine 'MPO OverlayTestMode' 'INFO' ($(if($null -eq $mpo){ 'Not set' }else{ [string]$mpo })))
        (ConvertTo-GPTOPTAuditLine 'Game DVR values' 'INFO' "GameDVR_Enabled=$gameDvrEnabled AppCaptureEnabled=$appCaptureEnabled")
        (ConvertTo-GPTOPTAuditLine 'Gaming service status' ($(if($gamingServices -match '=Running'){ 'GOOD' }else{ 'WARN' })) $gamingServices)
        (ConvertTo-GPTOPTAuditLine 'Pending reboot flags' ($(if($cbsPending -or $wuPending){ 'WARN' }else{ 'GOOD' })) "CBS=$cbsPending WU=$wuPending")
    )
    return Format-GPTOPTAuditRows 'Windows Gaming Health Audit' $rows
}

function Get-GPTOPTAppsToolsAudit {
    $toolNames = @('steam','obs64','RTSS','MSIAfterburner','CapFrameX','SteelSeriesGG','SteelSeriesSonar','nvidia-smi','winget')
    $rows = foreach($tool in $toolNames){
        $process = Get-GPTOPTProcessSummary @($tool)
        $command = Get-Command $tool -ErrorAction SilentlyContinue
        $state = if($process -ne 'Not detected' -or $command){ 'GOOD' }else{ 'UNKNOWN' }
        $detail = if($process -ne 'Not detected'){ "Running: $process" }elseif($command){ "Command: $($command.Source)" }else{ 'Not detected in process list or PATH' }
        ConvertTo-GPTOPTAuditLine $tool $state $detail
    }
    return Format-GPTOPTAuditRows 'Apps / Tools Audit' $rows
}

function Get-GPTOPTReportsAudit {
    param([string]$SessionRoot)
    $expandedRoot = [Environment]::ExpandEnvironmentVariables($SessionRoot)
    $sessions = @(if(Test-Path -LiteralPath $expandedRoot){ Get-ChildItem -LiteralPath $expandedRoot -Directory -Filter 'session_*' -ErrorAction SilentlyContinue }else{ @() })
    $zips = @(if(Test-Path -LiteralPath $expandedRoot){ Get-ChildItem -LiteralPath $expandedRoot -File -Filter '*_UPLOAD.zip' -ErrorAction SilentlyContinue }else{ @() })
    $latestSession = $sessions | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $latestZip = $zips | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $rows = @(
        (ConvertTo-GPTOPTAuditLine 'Session root' ($(if(Test-Path -LiteralPath $expandedRoot){ 'GOOD' }else{ 'UNKNOWN' })) $expandedRoot)
        (ConvertTo-GPTOPTAuditLine 'Session folders' ($(if($sessions.Count -gt 0){ 'GOOD' }else{ 'UNKNOWN' })) "$($sessions.Count) found")
        (ConvertTo-GPTOPTAuditLine 'Latest session' ($(if($latestSession){ 'GOOD' }else{ 'UNKNOWN' })) ($(if($latestSession){ $latestSession.FullName }else{ 'None found' })))
        (ConvertTo-GPTOPTAuditLine 'Upload packages' ($(if($zips.Count -gt 0){ 'GOOD' }else{ 'UNKNOWN' })) "$($zips.Count) found")
        (ConvertTo-GPTOPTAuditLine 'Latest upload zip' ($(if($latestZip){ 'GOOD' }else{ 'UNKNOWN' })) ($(if($latestZip){ $latestZip.FullName }else{ 'None found' })))
    )
    return Format-GPTOPTAuditRows 'Reports Audit' $rows
}

function Get-GPTOPTAdvancedRevertAudit {
    param([string]$RepoRoot)
    $revertFiles = @(
        'Registry\MPO-Restore.reg',
        'quality_mode.bat',
        'reset_tweaks.bat',
        'docs\ROLLBACK_GUIDE.md'
    )
    $rows = foreach($relative in $revertFiles){
        $path = Join-Path $RepoRoot $relative
        ConvertTo-GPTOPTAuditLine $relative ($(if(Test-Path -LiteralPath $path){ 'GOOD' }else{ 'WARN' })) ($(if(Test-Path -LiteralPath $path){ $path }else{ 'Missing' }))
    }
    $rows += ConvertTo-GPTOPTAuditLine 'Advanced / Revert action mode' 'INFO' 'Read-only inventory only. No revert actions are executed from this tab.'
    return Format-GPTOPTAuditRows 'Advanced / Revert Audit' $rows
}
