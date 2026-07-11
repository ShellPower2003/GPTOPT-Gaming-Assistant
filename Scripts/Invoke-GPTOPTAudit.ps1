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
    param([int]$Percent, [string]$Status)
    Write-Progress -Activity 'GPTOPT PC Audit' -Status ("{0}% - {1}" -f $Percent, $Status) -PercentComplete $Percent
}

function Get-RegValue {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name }
    catch { return $null }
}

function Get-Sha256Text {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Add-Line {
    param([System.Collections.Generic.List[string]]$List, [string]$Text = '')
    [void]$List.Add($Text)
}

function ConvertTo-SafeMarkdown {
    param([pscustomobject]$Report)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    Add-Line $lines '# GPTOPT Latest Sanitized PC Audit'
    Add-Line $lines ''
    Add-Line $lines '> Machine-generated. The full diagnostic archive remains local and is not uploaded.'
    Add-Line $lines ''
    Add-Line $lines ("- Audit ID: ``{0}``" -f $Report.audit_id)
    Add-Line $lines ("- Collected UTC: ``{0}``" -f $Report.collected_utc)
    Add-Line $lines ("- Machine key: ``{0}``" -f $Report.machine_key)
    Add-Line $lines ("- Collector: ``{0}``" -f $Report.collector_version)
    Add-Line $lines ''
    Add-Line $lines '## Platform'
    Add-Line $lines ("- Windows: {0}" -f $Report.platform.windows)
    Add-Line $lines ("- Build: {0}" -f $Report.platform.build)
    Add-Line $lines ("- BIOS: {0}" -f $Report.platform.bios)
    Add-Line $lines ("- CPU: {0}" -f $Report.platform.cpu)
    Add-Line $lines ("- GPU: {0}" -f $Report.platform.gpu)
    Add-Line $lines ("- Memory: {0} GB" -f $Report.platform.memory_gb)
    Add-Line $lines ("- Display: {0}" -f $Report.platform.display)
    Add-Line $lines ''
    Add-Line $lines '## Gaming configuration'
    Add-Line $lines ("- Active power plan: {0}" -f $Report.gaming.power_plan)
    Add-Line $lines ("- Game Mode: {0}" -f $Report.gaming.game_mode)
    Add-Line $lines ("- Game DVR: {0}" -f $Report.gaming.game_dvr)
    Add-Line $lines ("- HAGS registry value: {0}" -f $Report.gaming.hags)
    Add-Line $lines ("- MPO override: {0}" -f $Report.gaming.mpo_override)
    Add-Line $lines ''
    Add-Line $lines '## Devices and software'
    Add-Line $lines ("- Flydigi/Vader detected: {0}" -f $Report.devices.flydigi_detected)
    Add-Line $lines ("- NVIDIA driver: {0}" -f $Report.devices.nvidia_driver)
    Add-Line $lines ("- Active wired adapters: {0}" -f $Report.devices.active_wired_adapters)
    Add-Line $lines ("- Active Wi-Fi adapters: {0}" -f $Report.devices.active_wifi_adapters)
    Add-Line $lines ("- GPTOPT-related processes: {0}" -f ($Report.devices.gptopt_processes -join ', '))
    Add-Line $lines ''
    Add-Line $lines '## Health signals'
    Add-Line $lines ("- System critical/error events, last 72h: {0}" -f $Report.health.system_error_count)
    Add-Line $lines ("- Application critical/error events, last 72h: {0}" -f $Report.health.application_error_count)
    Add-Line $lines ("- Problem devices: {0}" -f $Report.health.problem_device_count)
    Add-Line $lines ("- Pending reboot indicators: {0}" -f $Report.health.pending_reboot_count)
    Add-Line $lines ("- System drive free: {0} GB" -f $Report.health.system_drive_free_gb)
    Add-Line $lines ''
    Add-Line $lines 'Raw paths, account names, addresses, identifiers, serial numbers, and event contents are intentionally excluded.'
    return ($lines -join "`n")
}

function Publish-LatestAuditIssue {
    param([string]$Repo, [string]$Title, [string]$Body, [string]$MachineKey)
    $gh = Get-Command gh.exe -ErrorAction SilentlyContinue
    if (-not $gh) { throw 'GitHub CLI (gh.exe) is required for -Publish.' }
    & $gh.Source auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated. Run: gh auth login' }
    $searchJson = & $gh.Source issue list --repo $Repo --state open --search ("[GPTOPT-AUDIT:{0}] in:title" -f $MachineKey) --json number,title --limit 10
    if ($LASTEXITCODE -ne 0) { throw 'Unable to query GPTOPT audit issues.' }
    $matches = @($searchJson | ConvertFrom-Json)
    $existing = $matches | Where-Object { $_.title -eq $Title } | Select-Object -First 1
    $temp = Join-Path $env:TEMP ("gptopt-audit-{0}.md" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $temp -Value $Body -Encoding UTF8
        if ($existing) {
            & $gh.Source issue edit $existing.number --repo $Repo --body-file $temp
            if ($LASTEXITCODE -ne 0) { throw 'Unable to update the latest-audit issue.' }
            return 'updated'
        }
        & $gh.Source issue create --repo $Repo --title $Title --body-file $temp
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create the latest-audit issue.' }
        return 'created'
    }
    finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$auditId = "GPTOPT-$stamp"
$runDir = Join-Path $AuditRoot $auditId
$rawDir = Join-Path $runDir 'raw'
New-Item -ItemType Directory -Path $rawDir -Force | Out-Null

Set-GPTOPTProgress 5 'Initializing local audit store'
$computer = Get-CimInstance Win32_ComputerSystem
$machineSeed = "{0}|{1}|{2}" -f $computer.Manufacturer, $computer.Model, $env:COMPUTERNAME
$machineKey = (Get-Sha256Text $machineSeed).Substring(0, 12)

Set-GPTOPTProgress 15 'Collecting platform inventory'
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = @(Get-CimInstance Win32_VideoController)
$bios = Get-CimInstance Win32_BIOS
$memoryBytes = (@(Get-CimInstance Win32_PhysicalMemory) | Measure-Object Capacity -Sum).Sum
$display = $gpus | Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1

Set-GPTOPTProgress 30 'Collecting gaming configuration'
$activePower = (powercfg.exe /getactivescheme 2>$null | Out-String).Trim()
$gameMode = Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'
$gameDvr = Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
$hags = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
$mpo = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'

Set-GPTOPTProgress 45 'Collecting devices and drivers'
$pnp = @(Get-PnpDevice -ErrorAction SilentlyContinue)
$flydigi = @($pnp | Where-Object { $_.FriendlyName -match 'Flydigi|Vader' }).Count -gt 0
$nvidia = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'NVIDIA.*(RTX|GeForce)' } | Select-Object -First 1
$net = @(Get-NetAdapter -ErrorAction SilentlyContinue)
$wiredCount = @($net | Where-Object { $_.Status -eq 'Up' -and $_.Name -notmatch 'Wi-Fi|Wireless' }).Count
$wifiCount = @($net | Where-Object { $_.Status -eq 'Up' -and $_.Name -match 'Wi-Fi|Wireless' }).Count
$knownProcesses = @('RTSS','MSIAfterburner','CapFrameX','PresentMon','GameControllerService','SteelSeriesGG','HaloInfinite')
$runningNames = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $knownProcesses -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)

Set-GPTOPTProgress 60 'Collecting health signals'
$since = (Get-Date).AddHours(-72)
$systemErrors = @(Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2; StartTime=$since } -ErrorAction SilentlyContinue).Count
$appErrors = @(Get-WinEvent -FilterHashtable @{ LogName='Application'; Level=1,2; StartTime=$since } -ErrorAction SilentlyContinue).Count
$problemDevices = @($pnp | Where-Object { $_.Status -notin @('OK','Unknown') }).Count
$pending = 0
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $pending++ }
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $pending++ }
try {
    $pendingRename = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations
    if ($pendingRename) { $pending++ }
} catch {}
$systemDrive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)

Set-GPTOPTProgress 72 'Writing private local snapshot'
$privateSnapshot = [ordered]@{
    audit_id = $auditId; collected_utc = (Get-Date).ToUniversalTime().ToString('o')
    computer = $computer; operating_system = $os; cpu = $cpu
    video_controllers = $gpus; bios = $bios
    physical_memory = @(Get-CimInstance Win32_PhysicalMemory)
    power_plan = $activePower; network_adapters = $net
    problem_devices = @($pnp | Where-Object { $_.Status -notin @('OK','Unknown') })
}
$privateSnapshot | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $rawDir 'private-snapshot.json') -Encoding UTF8
Get-CimInstance Win32_PnPSignedDriver | Export-Csv (Join-Path $rawDir 'signed-drivers.csv') -NoTypeInformation
powercfg.exe /query | Set-Content (Join-Path $rawDir 'powercfg.txt') -Encoding UTF8

Set-GPTOPTProgress 82 'Building sanitized report'
$displayText = 'Unavailable'
if ($display) { $displayText = "{0}x{1} @ {2} Hz" -f $display.CurrentHorizontalResolution, $display.CurrentVerticalResolution, $display.CurrentRefreshRate }
$gameModeText = if ($null -eq $gameMode) { 'Not set' } else { [string]$gameMode }
$gameDvrText = if ($null -eq $gameDvr) { 'Not set' } else { [string]$gameDvr }
$hagsText = if ($null -eq $hags) { 'Not set' } else { [string]$hags }
$mpoText = if ($null -eq $mpo) { 'Not set' } else { [string]$mpo }
$nvidiaText = if ($nvidia) { [string]$nvidia.DriverVersion } else { 'Not detected' }

$safeReport = [pscustomobject]@{
    schema_version = 1; collector_version = '0.3.0'; audit_id = $auditId
    collected_utc = (Get-Date).ToUniversalTime().ToString('o'); machine_key = $machineKey
    platform = [pscustomobject]@{
        windows = $os.Caption; build = $os.BuildNumber
        bios = "{0} {1}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion
        cpu = $cpu.Name.Trim(); gpu = (($gpus | Select-Object -ExpandProperty Name) -join '; ')
        memory_gb = [math]::Round($memoryBytes / 1GB, 1); display = $displayText
    }
    gaming = [pscustomobject]@{ power_plan=$activePower; game_mode=$gameModeText; game_dvr=$gameDvrText; hags=$hagsText; mpo_override=$mpoText }
    devices = [pscustomobject]@{ flydigi_detected=$flydigi; nvidia_driver=$nvidiaText; active_wired_adapters=$wiredCount; active_wifi_adapters=$wifiCount; gptopt_processes=$runningNames }
    health = [pscustomobject]@{ system_error_count=$systemErrors; application_error_count=$appErrors; problem_device_count=$problemDevices; pending_reboot_count=$pending; system_drive_free_gb=[math]::Round($systemDrive.FreeSpace / 1GB, 1) }
}

$safeJson = Join-Path $runDir 'GPTOPT-SanitizedReport.json'
$safeMd = Join-Path $runDir 'GPTOPT-SanitizedReport.md'
$safeReport | ConvertTo-Json -Depth 6 | Set-Content $safeJson -Encoding UTF8
$markdown = ConvertTo-SafeMarkdown $safeReport
Set-Content $safeMd -Value $markdown -Encoding UTF8

Set-GPTOPTProgress 88 'Updating latest local audit pointer'
$latestDir = Join-Path $AuditRoot 'latest'
if (Test-Path $latestDir) { Remove-Item $latestDir -Recurse -Force }
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
Copy-Item $safeJson,$safeMd -Destination $latestDir -Force
@{ audit_id=$auditId; run_directory=$runDir; collected_utc=$safeReport.collected_utc } | ConvertTo-Json | Set-Content (Join-Path $AuditRoot 'latest.json') -Encoding UTF8

Set-GPTOPTProgress 92 'Applying local history retention'
$history = @(Get-ChildItem $AuditRoot -Directory -Filter 'GPTOPT-*' | Sort-Object Name -Descending)
if ($history.Count -gt $HistoryLimit) { $history | Select-Object -Skip $HistoryLimit | Remove-Item -Recurse -Force }

$publishResult = 'not requested'
if ($Publish) {
    Set-GPTOPTProgress 96 'Publishing sanitized latest-audit issue'
    $title = "[GPTOPT-AUDIT:{0}] Latest PC Audit" -f $machineKey
    $publishResult = Publish-LatestAuditIssue -Repo $Repository -Title $title -Body $markdown -MachineKey $machineKey
}

Set-GPTOPTProgress 100 'Complete'
Start-Sleep -Milliseconds 500
Write-Progress -Activity 'GPTOPT PC Audit' -Completed
Write-Host ''
Write-Host 'GPTOPT AUDIT 100% COMPLETE' -ForegroundColor Green
Write-Host ("Private audit: {0}" -f $runDir) -ForegroundColor Cyan
Write-Host ("Sanitized latest: {0}" -f $safeMd) -ForegroundColor Cyan
Write-Host ("GitHub summary: {0}" -f $publishResult) -ForegroundColor Green
Write-Host ''
