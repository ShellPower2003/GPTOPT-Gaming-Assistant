#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$Repository = 'ShellPower2003/GPTOPT-Gaming-Assistant',
    [string]$AuditRoot = (Join-Path $env:LOCALAPPDATA 'GPTOPT\Audits'),
    [int]$HistoryLimit = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

function Set-GPTOPTProgress { param([int]$Percent,[string]$Status) Write-Progress -Activity 'GPTOPT PC Audit' -Status ("{0}% - {1}" -f $Percent,$Status) -PercentComplete $Percent }
function Get-RegValue { param([string]$Path,[string]$Name) try { (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { $null } }
function Get-Sha256Text { param([string]$Text) $sha=[Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() } }
function ConvertTo-PlainRecords { param([object[]]$InputObject,[string[]]$Property) @(foreach($item in @($InputObject)){if($null -eq $item){continue};$record=[ordered]@{};foreach($name in $Property){$record[$name]=$item.$name};[pscustomobject]$record}) }
function Get-EventCount { param([string]$Log,[datetime]$Since,[string[]]$Providers,[int[]]$Ids) @((Get-WinEvent -FilterHashtable @{LogName=$Log;StartTime=$Since;Level=1,2,3} -ErrorAction SilentlyContinue) | Where-Object { ($Providers -contains $_.ProviderName) -or ($Ids.Count -gt 0 -and $Ids -contains $_.Id) }).Count }

function Get-CrashSummary {
    param([datetime]$Since)
    $gamingPattern='HaloInfinite|CapFrameX|PresentMon|RTSS|MSIAfterburner|GameControllerService|SteelSeries|NVIDIA|nvcontainer|Flydigi|SpaceStation'
    $rows=@()
    foreach($e in @(Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$Since;Id=1000,1001} -ErrorAction SilentlyContinue)){
        $name=$null
        if($e.ProviderName -eq 'Application Error' -and $e.Properties.Count -gt 0){$name=[string]$e.Properties[0].Value}
        if(-not $name -and $e.Message -match '(?im)Faulting application name:\s*([^,\r\n]+)'){$name=$matches[1].Trim()}
        if(-not $name -and $e.Message -match '(?im)AppName=([^\r\n]+)'){$name=$matches[1].Trim()}
        if(-not $name){$name=$e.ProviderName}
        $rows += [pscustomobject]@{Application=$name;Time=$e.TimeCreated;Relevant=($name -match $gamingPattern)}
    }
    $gaming=@($rows|Where-Object Relevant)
    $background=@($rows|Where-Object {-not $_.Relevant})
    [pscustomobject]@{
        gaming_count=$gaming.Count
        background_count=$background.Count
        gaming_apps=@($gaming|Group-Object Application|Sort-Object Count -Descending|ForEach-Object{"$($_.Name) ($($_.Count))"})
        background_apps=@($background|Group-Object Application|Sort-Object Count -Descending|Select-Object -First 8|ForEach-Object{"$($_.Name) ($($_.Count))"})
    }
}

function ConvertTo-SafeMarkdown {
    param([pscustomobject]$Report)
    @(
        '# GPTOPT Latest Sanitized PC Audit','',
        '> Machine-generated. The full diagnostic archive remains local and is not uploaded.','',
        "- Audit ID: ``$($Report.audit_id)``",
        "- Collected UTC: ``$($Report.collected_utc)``",
        "- Machine key: ``$($Report.machine_key)``",
        "- Collector: ``$($Report.collector_version)``",'',
        '## Gaming readiness',
        "- Status: **$($Report.readiness.status)**",
        "- Score: **$($Report.readiness.score)/100**",
        "- Summary: $($Report.readiness.summary)",
        "- Blockers: $($Report.readiness.blockers -join '; ')",
        "- Warnings: $($Report.readiness.warnings -join '; ')",
        "- Passed checks: $($Report.readiness.passed_checks -join '; ')",'',
        '## Platform',
        "- Windows: $($Report.platform.windows)","- Build: $($Report.platform.build)","- BIOS: $($Report.platform.bios)","- CPU: $($Report.platform.cpu)","- GPU: $($Report.platform.gpu)","- Memory: $($Report.platform.memory_gb) GB","- Display: $($Report.platform.display)",'',
        '## Gaming configuration',
        "- Active power plan: $($Report.gaming.power_plan)","- Game Mode: $($Report.gaming.game_mode)","- Game DVR: $($Report.gaming.game_dvr)","- HAGS registry value: $($Report.gaming.hags)","- MPO override: $($Report.gaming.mpo_override)",'',
        '## Devices and software',
        "- Flydigi/Vader detected: $($Report.devices.flydigi_detected)","- Flydigi evidence: $($Report.devices.flydigi_evidence -join ', ')","- NVIDIA driver: $($Report.devices.nvidia_driver)","- Active wired adapters: $($Report.devices.active_wired_adapters)","- Active Wi-Fi adapters: $($Report.devices.active_wifi_adapters)","- GPTOPT-related processes: $($Report.devices.gptopt_processes -join ', ')",'',
        '## Gaming-relevant health',
        "- WHEA events: $($Report.health.whea_count)","- Display/GPU reset events: $($Report.health.display_reset_count)","- Storage fault events: $($Report.health.storage_fault_count)","- Controller/USB fault events: $($Report.health.controller_fault_count)","- Gaming-related crashes: $($Report.health.gaming_crash_count)","- Gaming crash apps: $($Report.health.gaming_crash_apps -join ', ')","- Background/non-gaming crashes: $($Report.health.background_crash_count)",'',
        '## Actionable state',
        "- Problem devices: $($Report.health.problem_device_count)","- Problem device names: $($Report.health.problem_device_names -join ', ')","- Pending reboot sources: $($Report.health.pending_reboot_sources -join ', ')","- Pending rename files: $($Report.health.pending_rename_files -join ', ')","- System drive free: $($Report.health.system_drive_free_gb) GB",'',
        'Raw paths, account names, addresses, identifiers, serial numbers, and full event contents are intentionally excluded.'
    ) -join "`n"
}

function Publish-LatestAuditIssue {
    param([string]$Repo,[string]$Title,[string]$Body,[string]$MachineKey,[string]$AuditId)
    $gh=Get-Command gh.exe -ErrorAction SilentlyContinue
    if(-not $gh){throw 'GitHub CLI (gh.exe) is required for Publish.'}
    & $gh.Source auth status --hostname github.com *> $null
    if($LASTEXITCODE -ne 0){throw 'GitHub CLI is not authenticated. Run gh auth login.'}
    $search=& $gh.Source issue list --repo $Repo --state open --search ("[GPTOPT-AUDIT:{0}] in:title" -f $MachineKey) --json number,title --limit 10
    if($LASTEXITCODE -ne 0){throw 'Unable to query GPTOPT audit issues.'}
    $existing=@($search|ConvertFrom-Json)|Where-Object title -eq $Title|Select-Object -First 1
    $temp=Join-Path $env:TEMP ("gptopt-audit-{0}.md" -f [guid]::NewGuid().ToString('N'))
    try{
        Set-Content -LiteralPath $temp -Value $Body -Encoding UTF8
        if($existing){
            & $gh.Source issue edit $existing.number --repo $Repo --body-file $temp
            if($LASTEXITCODE -ne 0){throw 'Unable to update audit issue.'}
            $number=$existing.number
        }else{
            $url=& $gh.Source issue create --repo $Repo --title $Title --body-file $temp
            if($LASTEXITCODE -ne 0){throw 'Unable to create audit issue.'}
            $number=($url|Select-String -Pattern '(\d+)$').Matches[0].Groups[1].Value
        }
        $published=& $gh.Source issue view $number --repo $Repo --json body,url
        if($LASTEXITCODE -ne 0){throw 'Audit issue was written but could not be verified.'}
        $verified=$published|ConvertFrom-Json
        if($verified.body -notmatch [regex]::Escape($AuditId)){throw "Publish verification failed: GitHub issue does not contain $AuditId"}
        return $verified.url
    }finally{Remove-Item $temp -Force -ErrorAction SilentlyContinue}
}

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$auditId="GPTOPT-$stamp";$runDir=Join-Path $AuditRoot $auditId;$rawDir=Join-Path $runDir 'raw';New-Item -ItemType Directory -Path $rawDir -Force|Out-Null
Set-GPTOPTProgress 5 'Initializing local audit store'
$computer=Get-CimInstance Win32_ComputerSystem;$machineKey=(Get-Sha256Text ("{0}|{1}|{2}" -f $computer.Manufacturer,$computer.Model,$env:COMPUTERNAME)).Substring(0,12)
Set-GPTOPTProgress 14 'Collecting platform inventory'
$os=Get-CimInstance Win32_OperatingSystem;$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1;$gpus=@(Get-CimInstance Win32_VideoController);$bios=Get-CimInstance Win32_BIOS;$memory=@(Get-CimInstance Win32_PhysicalMemory);$memoryBytes=($memory|Measure-Object Capacity -Sum).Sum;$display=$gpus|Where-Object CurrentHorizontalResolution|Select-Object -First 1
Set-GPTOPTProgress 28 'Collecting gaming configuration'
$activePower=(powercfg.exe /getactivescheme 2>$null|Out-String).Trim();$gameMode=Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode';$gameDvr=Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled';$hags=Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode';$mpo=Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
Set-GPTOPTProgress 42 'Collecting devices and drivers'
$pnp=@(Get-PnpDevice -ErrorAction SilentlyContinue);$processes=@(Get-Process -ErrorAction SilentlyContinue);$known='RTSS','MSIAfterburner','CapFrameX','PresentMon','IntelPresentMon','GameControllerService','SteelSeriesGG','HaloInfinite';$running=@($processes|Where-Object{$known -contains $_.ProcessName}|Select-Object -ExpandProperty ProcessName -Unique|Sort-Object)
$flydigiEvidence=@();if(@($pnp|Where-Object{$_.FriendlyName -match 'Flydigi|Vader'}).Count -gt 0){$flydigiEvidence+='PnP name'};if(@($pnp|Where-Object{$_.InstanceId -match 'VID_045E&PID_028E|FLYDIGI_VADER4'}).Count -gt 0){$flydigiEvidence+='USB/HID ID'};if($running -contains 'GameControllerService'){$flydigiEvidence+='GameControllerService'};$flydigi=$flydigiEvidence.Count -gt 0
$nvidia=Get-CimInstance Win32_PnPSignedDriver|Where-Object DeviceName -match 'NVIDIA.*(RTX|GeForce)'|Select-Object -First 1;$net=@(Get-NetAdapter -ErrorAction SilentlyContinue);$wiredCount=@($net|Where-Object{$_.Status -eq 'Up' -and $_.Name -notmatch 'Wi-Fi|Wireless'}).Count;$wifiCount=@($net|Where-Object{$_.Status -eq 'Up' -and $_.Name -match 'Wi-Fi|Wireless'}).Count
Set-GPTOPTProgress 56 'Classifying gaming-relevant health signals'
$since=(Get-Date).AddHours(-72);$systemErrors=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=$since} -ErrorAction SilentlyContinue).Count;$appErrors=@(Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2;StartTime=$since} -ErrorAction SilentlyContinue).Count
$whea=Get-EventCount 'System' $since @('Microsoft-Windows-WHEA-Logger') @();$displayResets=Get-EventCount 'System' $since @('Display','nvlddmkm') @(4101);$storageFaults=Get-EventCount 'System' $since @('disk','stornvme','storahci','Ntfs') @(7,11,51,55,129,153);$controllerFaults=Get-EventCount 'System' $since @('Microsoft-Windows-Kernel-PnP','Kernel-PnP','USBHUB3','Microsoft-Windows-DriverFrameworks-UserMode') @(2003,2100,2102,219)
$crashSummary=Get-CrashSummary $since
$problem=@($pnp|Where-Object{$_.Present -ne $false -and $_.Status -notin 'OK','Unknown' -and $_.Problem -notin 0,$null});$problemNames=@($problem|ForEach-Object{$_.FriendlyName}|Where-Object{$_}|Sort-Object -Unique)
$rename=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations;$renameFiles=@($rename|Where-Object{$_}|ForEach-Object{Split-Path $_ -Leaf}|Where-Object{$_}|Sort-Object -Unique)
$pendingSources=@();if(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'){$pendingSources+='Windows Update'};if(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'){$pendingSources+='Component Servicing'};if(@($rename).Count -gt 0){$pendingSources+='Pending file rename'}
$systemDrive=Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)
$blockers=@();$warnings=@();$passed=@()
if($whea -gt 0){$blockers+="$whea WHEA hardware event(s)"}else{$passed+='No WHEA hardware instability'}
if($displayResets -gt 0){$blockers+="$displayResets GPU/display reset event(s)"}else{$passed+='No GPU/display resets'}
if($storageFaults -gt 0){$blockers+="$storageFaults storage fault event(s)"}else{$passed+='No storage timeouts or faults'}
if($problem.Count -gt 0){$blockers+="$($problem.Count) active problem device(s): $($problemNames -join ', ')"}else{$passed+='No active problem devices'}
if($crashSummary.gaming_count -gt 0){$warnings+="$($crashSummary.gaming_count) gaming-related application crash(es): $($crashSummary.gaming_apps -join ', ')"}else{$passed+='No gaming-related application crashes'}
if($controllerFaults -gt 0){$warnings+="$controllerFaults controller/USB event(s) need review"}else{$passed+='No controller/USB fault events'}
if(-not $flydigi){$warnings+='Flydigi/Vader path not detected'}else{$passed+='Flydigi/Vader path detected'}
if($wiredCount -eq 0){$warnings+='No active wired network adapter'}else{$passed+='Wired network active'}
if($pendingSources.Count -gt 0){
    if($pendingSources.Count -eq 1 -and $renameFiles -contains 'gamingservicesproxy_11.dll.0'){$warnings+='Stale Gaming Services rename entry; reboot or targeted cleanup recommended'}
    else{$warnings+="Pending reboot: $($pendingSources -join ', ')"}
}else{$passed+='No pending reboot'}
$score=100-($blockers.Count*18)-([math]::Min($warnings.Count*4,20));$score=[math]::Max(0,[math]::Min(100,$score));$status=if($blockers.Count -gt 0){'NOT READY'}elseif($warnings.Count -gt 0){'READY WITH MINOR ISSUES'}else{'READY'};$summary=if($blockers.Count -gt 0){'Resolve the blocking hardware or driver findings before judging game performance.'}elseif($warnings.Count -gt 0){'Safe to play. Review the listed minor issues when convenient.'}else{'Core gaming, hardware, controller, and network checks passed.'}
Set-GPTOPTProgress 70 'Writing private and sanitized snapshots'
$private=[ordered]@{audit_id=$auditId;collected_utc=(Get-Date).ToUniversalTime().ToString('o');problem_devices=ConvertTo-PlainRecords $problem @('Class','FriendlyName','Status','Problem');pending_reboot_sources=$pendingSources;pending_rename_files=$renameFiles;flydigi_evidence=$flydigiEvidence;gaming_crash_apps=$crashSummary.gaming_apps;background_crash_apps=$crashSummary.background_apps}
$private|ConvertTo-Json -Depth 8|Set-Content (Join-Path $rawDir 'private-snapshot.json') -Encoding UTF8
$displayText=if($display){"$($display.CurrentHorizontalResolution)x$($display.CurrentVerticalResolution) @ $($display.CurrentRefreshRate) Hz"}else{'Unavailable'};$text={param($v)if($null -eq $v){'Not set'}else{[string]$v}}
$safe=[pscustomobject]@{schema_version=2;collector_version='0.4.0';audit_id=$auditId;collected_utc=(Get-Date).ToUniversalTime().ToString('o');machine_key=$machineKey;platform=[pscustomobject]@{windows=$os.Caption;build=$os.BuildNumber;bios=("{0} {1}" -f $bios.Manufacturer,$bios.SMBIOSBIOSVersion);cpu=$cpu.Name.Trim();gpu=(($gpus.Name)-join '; ');memory_gb=[math]::Round($memoryBytes/1GB,1);display=$displayText};gaming=[pscustomobject]@{power_plan=$activePower;game_mode=(& $text $gameMode);game_dvr=(& $text $gameDvr);hags=(& $text $hags);mpo_override=(& $text $mpo)};devices=[pscustomobject]@{flydigi_detected=$flydigi;flydigi_evidence=$flydigiEvidence;nvidia_driver=$(if($nvidia){$nvidia.DriverVersion}else{'Not detected'});active_wired_adapters=$wiredCount;active_wifi_adapters=$wifiCount;gptopt_processes=$running};health=[pscustomobject]@{system_error_count=$systemErrors;application_error_count=$appErrors;problem_device_count=$problem.Count;problem_device_names=$problemNames;pending_reboot_count=$pendingSources.Count;pending_reboot_sources=$pendingSources;pending_rename_files=$renameFiles;system_drive_free_gb=[math]::Round($systemDrive.FreeSpace/1GB,1);whea_count=$whea;display_reset_count=$displayResets;storage_fault_count=$storageFaults;controller_fault_count=$controllerFaults;gaming_crash_count=$crashSummary.gaming_count;background_crash_count=$crashSummary.background_count;gaming_crash_apps=$crashSummary.gaming_apps;background_crash_apps=$crashSummary.background_apps};readiness=[pscustomobject]@{score=$score;status=$status;summary=$summary;blockers=$blockers;warnings=$warnings;passed_checks=$passed}}
$safeJson=Join-Path $runDir 'GPTOPT-SanitizedReport.json';$safeMd=Join-Path $runDir 'GPTOPT-SanitizedReport.md';$safe|ConvertTo-Json -Depth 8|Set-Content $safeJson -Encoding UTF8;$markdown=ConvertTo-SafeMarkdown $safe;Set-Content $safeMd -Value $markdown -Encoding UTF8
Set-GPTOPTProgress 84 'Updating latest local audit pointer'
$latest=Join-Path $AuditRoot 'latest';if(Test-Path $latest){Remove-Item $latest -Recurse -Force};New-Item -ItemType Directory $latest -Force|Out-Null;Copy-Item $safeJson,$safeMd -Destination $latest -Force;@{audit_id=$auditId;run_directory=$runDir;collected_utc=$safe.collected_utc}|ConvertTo-Json|Set-Content (Join-Path $AuditRoot 'latest.json') -Encoding UTF8
Set-GPTOPTProgress 90 'Applying local history retention';$history=@(Get-ChildItem $AuditRoot -Directory -Filter 'GPTOPT-*'|Sort-Object Name -Descending);if($history.Count -gt $HistoryLimit){$history|Select-Object -Skip $HistoryLimit|Remove-Item -Recurse -Force}
$publishResult='not requested';if($Publish){Set-GPTOPTProgress 95 'Publishing and verifying latest audit';$title="[GPTOPT-AUDIT:$machineKey] Latest PC Audit";$publishResult=Publish-LatestAuditIssue $Repository $title $markdown $machineKey $auditId}
Set-GPTOPTProgress 100 'Complete';Write-Progress -Activity 'GPTOPT PC Audit' -Completed;Write-Host '';Write-Host 'GPTOPT AUDIT 100% COMPLETE' -ForegroundColor Green;Write-Host "Readiness: $status ($score/100)" -ForegroundColor Cyan;Write-Host "Private audit: $runDir" -ForegroundColor Cyan;Write-Host "Sanitized latest: $safeMd" -ForegroundColor Cyan;Write-Host "GitHub summary: $publishResult" -ForegroundColor Green;Write-Host ''
