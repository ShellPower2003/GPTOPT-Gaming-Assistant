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

function Set-GPTOPTProgress {
    param([int]$Percent,[string]$Status)
    Write-Progress -Activity 'GPTOPT PC Audit' -Status ("{0}% - {1}" -f $Percent,$Status) -PercentComplete $Percent
}

function Get-RegValue {
    param([string]$Path,[string]$Name)
    try { (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Get-Sha256Text {
    param([string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function ConvertTo-PlainRecords {
    param([object[]]$InputObject,[string[]]$Property)
    @(
        foreach($item in @($InputObject)) {
            if($null -eq $item){ continue }
            $record=[ordered]@{}
            foreach($name in $Property){ $record[$name]=$item.$name }
            [pscustomobject]$record
        }
    )
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
        '## Platform',
        "- Windows: $($Report.platform.windows)",
        "- Build: $($Report.platform.build)",
        "- BIOS: $($Report.platform.bios)",
        "- CPU: $($Report.platform.cpu)",
        "- GPU: $($Report.platform.gpu)",
        "- Memory: $($Report.platform.memory_gb) GB",
        "- Display: $($Report.platform.display)",'',
        '## Gaming configuration',
        "- Active power plan: $($Report.gaming.power_plan)",
        "- Game Mode: $($Report.gaming.game_mode)",
        "- Game DVR: $($Report.gaming.game_dvr)",
        "- HAGS registry value: $($Report.gaming.hags)",
        "- MPO override: $($Report.gaming.mpo_override)",'',
        '## Devices and software',
        "- Flydigi/Vader detected: $($Report.devices.flydigi_detected)",
        "- Flydigi evidence: $($Report.devices.flydigi_evidence -join ', ')",
        "- NVIDIA driver: $($Report.devices.nvidia_driver)",
        "- Active wired adapters: $($Report.devices.active_wired_adapters)",
        "- Active Wi-Fi adapters: $($Report.devices.active_wifi_adapters)",
        "- GPTOPT-related processes: $($Report.devices.gptopt_processes -join ', ')",'',
        '## Health signals',
        "- System critical/error events, last 72h: $($Report.health.system_error_count)",
        "- Application critical/error events, last 72h: $($Report.health.application_error_count)",
        "- Problem devices: $($Report.health.problem_device_count)",
        "- Problem device classes: $($Report.health.problem_device_classes -join ', ')",
        "- Pending reboot indicators: $($Report.health.pending_reboot_count)",
        "- Pending reboot sources: $($Report.health.pending_reboot_sources -join ', ')",
        "- System drive free: $($Report.health.system_drive_free_gb) GB",'',
        'Raw paths, account names, addresses, identifiers, serial numbers, and event contents are intentionally excluded.'
    ) -join "`n"
}

function Publish-LatestAuditIssue {
    param([string]$Repo,[string]$Title,[string]$Body,[string]$MachineKey)
    $gh=Get-Command gh.exe -ErrorAction SilentlyContinue
    if(-not $gh){ throw 'GitHub CLI (gh.exe) is required for -Publish.' }
    & $gh.Source auth status --hostname github.com *> $null
    if($LASTEXITCODE -ne 0){ throw 'GitHub CLI is not authenticated. Run: gh auth login' }
    $search=& $gh.Source issue list --repo $Repo --state open --search ("[GPTOPT-AUDIT:{0}] in:title" -f $MachineKey) --json number,title --limit 10
    if($LASTEXITCODE -ne 0){ throw 'Unable to query GPTOPT audit issues.' }
    $existing=@($search | ConvertFrom-Json) | Where-Object title -eq $Title | Select-Object -First 1
    $temp=Join-Path $env:TEMP ("gptopt-audit-{0}.md" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $temp -Value $Body -Encoding UTF8
        if($existing){
            & $gh.Source issue edit $existing.number --repo $Repo --body-file $temp
            if($LASTEXITCODE -ne 0){throw 'Unable to update audit issue.'}
            return (& $gh.Source issue view $existing.number --repo $Repo --json url --jq .url)
        }
        $url=& $gh.Source issue create --repo $Repo --title $Title --body-file $temp
        if($LASTEXITCODE -ne 0){throw 'Unable to create audit issue.'}
        return $url
    } finally { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
}

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$auditId="GPTOPT-$stamp"
$runDir=Join-Path $AuditRoot $auditId
$rawDir=Join-Path $runDir 'raw'
New-Item -ItemType Directory -Path $rawDir -Force | Out-Null

Set-GPTOPTProgress 5 'Initializing local audit store'
$computer=Get-CimInstance Win32_ComputerSystem
$machineKey=(Get-Sha256Text ("{0}|{1}|{2}" -f $computer.Manufacturer,$computer.Model,$env:COMPUTERNAME)).Substring(0,12)

Set-GPTOPTProgress 15 'Collecting platform inventory'
$os=Get-CimInstance Win32_OperatingSystem
$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus=@(Get-CimInstance Win32_VideoController)
$bios=Get-CimInstance Win32_BIOS
$memory=@(Get-CimInstance Win32_PhysicalMemory)
$memoryBytes=($memory | Measure-Object Capacity -Sum).Sum
$display=$gpus | Where-Object CurrentHorizontalResolution | Select-Object -First 1

Set-GPTOPTProgress 30 'Collecting gaming configuration'
$activePower=(powercfg.exe /getactivescheme 2>$null | Out-String).Trim()
$gameMode=Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'
$gameDvr=Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
$hags=Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
$mpo=Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'

Set-GPTOPTProgress 45 'Collecting devices and drivers'
$pnp=@(Get-PnpDevice -ErrorAction SilentlyContinue)
$processes=@(Get-Process -ErrorAction SilentlyContinue)
$known='RTSS','MSIAfterburner','CapFrameX','PresentMon','GameControllerService','SteelSeriesGG','HaloInfinite'
$running=@($processes | Where-Object { $known -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)
$flydigiEvidence=@()
if(@($pnp | Where-Object { $_.FriendlyName -match 'Flydigi|Vader' }).Count -gt 0){$flydigiEvidence+='PnP name'}
if(@($pnp | Where-Object { $_.InstanceId -match 'VID_045E&PID_028E|FLYDIGI_VADER4' }).Count -gt 0){$flydigiEvidence+='USB/HID ID'}
if($running -contains 'GameControllerService'){$flydigiEvidence+='GameControllerService'}
$flydigi=$flydigiEvidence.Count -gt 0
$nvidia=Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName -match 'NVIDIA.*(RTX|GeForce)' | Select-Object -First 1
$net=@(Get-NetAdapter -ErrorAction SilentlyContinue)
$wiredCount=@($net | Where-Object { $_.Status -eq 'Up' -and $_.Name -notmatch 'Wi-Fi|Wireless' }).Count
$wifiCount=@($net | Where-Object { $_.Status -eq 'Up' -and $_.Name -match 'Wi-Fi|Wireless' }).Count

Set-GPTOPTProgress 60 'Collecting health signals'
$since=(Get-Date).AddHours(-72)
$systemErrors=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=$since} -ErrorAction SilentlyContinue).Count
$appErrors=@(Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2;StartTime=$since} -ErrorAction SilentlyContinue).Count
$problem=@($pnp | Where-Object { $_.Status -notin 'OK','Unknown' })
$pendingSources=@()
if(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'){$pendingSources+='Windows Update'}
if(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'){$pendingSources+='Component Servicing'}
try{if((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations){$pendingSources+='Pending file rename'}}catch{}
$systemDrive=Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)

Set-GPTOPTProgress 72 'Writing private local snapshot'
$private=[ordered]@{
 audit_id=$auditId; collected_utc=(Get-Date).ToUniversalTime().ToString('o')
 computer=ConvertTo-PlainRecords $computer @('Manufacturer','Model','TotalPhysicalMemory','NumberOfLogicalProcessors','HypervisorPresent')
 operating_system=ConvertTo-PlainRecords $os @('Caption','Version','BuildNumber','OSArchitecture','LastBootUpTime','FreePhysicalMemory')
 cpu=ConvertTo-PlainRecords $cpu @('Name','NumberOfCores','NumberOfLogicalProcessors','MaxClockSpeed','CurrentClockSpeed')
 video_controllers=ConvertTo-PlainRecords $gpus @('Name','DriverVersion','AdapterRAM','CurrentHorizontalResolution','CurrentVerticalResolution','CurrentRefreshRate')
 bios=ConvertTo-PlainRecords $bios @('Manufacturer','SMBIOSBIOSVersion','ReleaseDate')
 physical_memory=ConvertTo-PlainRecords $memory @('Manufacturer','PartNumber','Capacity','Speed','ConfiguredClockSpeed')
 power_plan=$activePower
 network_adapters=ConvertTo-PlainRecords $net @('Name','InterfaceDescription','Status','LinkSpeed','DriverVersion')
 problem_devices=ConvertTo-PlainRecords $problem @('Class','FriendlyName','Status','Problem')
 pending_reboot_sources=$pendingSources
 flydigi_evidence=$flydigiEvidence
}
$private | ConvertTo-Json -Depth 8 -WarningAction SilentlyContinue | Set-Content (Join-Path $rawDir 'private-snapshot.json') -Encoding UTF8
Get-CimInstance Win32_PnPSignedDriver | Select-Object DeviceName,DeviceClass,Manufacturer,DriverProviderName,DriverVersion,DriverDate,InfName | Export-Csv (Join-Path $rawDir 'signed-drivers.csv') -NoTypeInformation
powercfg.exe /query | Set-Content (Join-Path $rawDir 'powercfg.txt') -Encoding UTF8

Set-GPTOPTProgress 82 'Building sanitized report'
$displayText=if($display){"$($display.CurrentHorizontalResolution)x$($display.CurrentVerticalResolution) @ $($display.CurrentRefreshRate) Hz"}else{'Unavailable'}
$text={param($v) if($null -eq $v){'Not set'}else{[string]$v}}
$safe=[pscustomobject]@{
 schema_version=1; collector_version='0.3.2'; audit_id=$auditId; collected_utc=(Get-Date).ToUniversalTime().ToString('o'); machine_key=$machineKey
 platform=[pscustomobject]@{windows=$os.Caption;build=$os.BuildNumber;bios=("{0} {1}" -f $bios.Manufacturer,$bios.SMBIOSBIOSVersion);cpu=$cpu.Name.Trim();gpu=(($gpus.Name)-join '; ');memory_gb=[math]::Round($memoryBytes/1GB,1);display=$displayText}
 gaming=[pscustomobject]@{power_plan=$activePower;game_mode=(& $text $gameMode);game_dvr=(& $text $gameDvr);hags=(& $text $hags);mpo_override=(& $text $mpo)}
 devices=[pscustomobject]@{flydigi_detected=$flydigi;flydigi_evidence=$flydigiEvidence;nvidia_driver=$(if($nvidia){$nvidia.DriverVersion}else{'Not detected'});active_wired_adapters=$wiredCount;active_wifi_adapters=$wifiCount;gptopt_processes=$running}
 health=[pscustomobject]@{system_error_count=$systemErrors;application_error_count=$appErrors;problem_device_count=$problem.Count;problem_device_classes=@($problem.Class|Where-Object{$_}|Sort-Object -Unique);pending_reboot_count=$pendingSources.Count;pending_reboot_sources=$pendingSources;system_drive_free_gb=[math]::Round($systemDrive.FreeSpace/1GB,1)}
}
$safeJson=Join-Path $runDir 'GPTOPT-SanitizedReport.json'; $safeMd=Join-Path $runDir 'GPTOPT-SanitizedReport.md'
$safe | ConvertTo-Json -Depth 6 | Set-Content $safeJson -Encoding UTF8
$markdown=ConvertTo-SafeMarkdown $safe
Set-Content $safeMd -Value $markdown -Encoding UTF8

Set-GPTOPTProgress 88 'Updating latest local audit pointer'
$latest=Join-Path $AuditRoot 'latest'; if(Test-Path $latest){Remove-Item $latest -Recurse -Force}; New-Item -ItemType Directory $latest -Force | Out-Null
Copy-Item $safeJson,$safeMd -Destination $latest -Force
@{audit_id=$auditId;run_directory=$runDir;collected_utc=$safe.collected_utc}|ConvertTo-Json|Set-Content (Join-Path $AuditRoot 'latest.json') -Encoding UTF8
Set-GPTOPTProgress 92 'Applying local history retention'
$history=@(Get-ChildItem $AuditRoot -Directory -Filter 'GPTOPT-*'|Sort-Object Name -Descending); if($history.Count -gt $HistoryLimit){$history|Select-Object -Skip $HistoryLimit|Remove-Item -Recurse -Force}
$publishResult='not requested'
if($Publish){Set-GPTOPTProgress 96 'Publishing sanitized latest-audit issue';$title="[GPTOPT-AUDIT:$machineKey] Latest PC Audit";$publishResult=Publish-LatestAuditIssue $Repository $title $markdown $machineKey}
Set-GPTOPTProgress 100 'Complete';Start-Sleep -Milliseconds 400;Write-Progress -Activity 'GPTOPT PC Audit' -Completed
Write-Host '';Write-Host 'GPTOPT AUDIT 100% COMPLETE' -ForegroundColor Green;Write-Host "Private audit: $runDir" -ForegroundColor Cyan;Write-Host "Sanitized latest: $safeMd" -ForegroundColor Cyan;Write-Host "GitHub summary: $publishResult" -ForegroundColor Green;Write-Host ''
