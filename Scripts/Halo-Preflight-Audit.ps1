<#
GPTOPT Halo Preflight Audit
Safe audit only. No changes. No reboot.
Saves report to Desktop\GPTOPT-Logs.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

# Create log directory on the user's desktop
$LogRoot = Join-Path $env:USERPROFILE 'Desktop' | Join-Path -ChildPath 'GPTOPT-Logs'
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null

# Unique timestamp for the audit run
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $LogRoot "Halo-Preflight-Audit-$Stamp.txt"
$JsonPath   = Join-Path $LogRoot "Halo-Preflight-Audit-$Stamp.json"

# Results collection
$Results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [ValidateSet('PASS','WARN','ACTION','INFO')]
        [string]$Status,
        [string]$Check,
        [string]$Detail,
        [string]$Recommendation = ''
    )

    $obj = [pscustomobject]@{
        Time           = (Get-Date).ToString('s')
        Status         = $Status
        Check          = $Check
        Detail         = $Detail
        Recommendation = $Recommendation
    }

    $Results.Add($obj) | Out-Null

    $color = switch ($Status) {
        'PASS'   { 'Green' }
        'WARN'   { 'Yellow' }
        'ACTION' { 'Red' }
        default  { 'Cyan' }
    }

    Write-Host ("[{0}] {1} - {2}" -f $Status, $Check, $Detail) -ForegroundColor $color
    if ($Recommendation) {
        Write-Host ("       -> {0}" -f $Recommendation) -ForegroundColor DarkGray
    }
}

function Get-RegValue {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    } catch {
        return $null
    }
}

function Test-ProcessRunning {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($p) {
            return $true
        }
    }
    return $false
}

Add-Result -Status INFO -Check 'Audit Mode' -Detail 'Read-only checks only. No settings changed.'

# Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if ($isAdmin) {
    Add-Result -Status PASS -Check 'PowerShell Admin' -Detail 'Running as Administrator.'
} else {
    Add-Result -Status WARN -Check 'PowerShell Admin' -Detail 'Not running as Administrator.' -Recommendation 'Re-run PowerShell as Admin for complete registry/service checks.'
}

# OS information
$os = Get-CimInstance Win32_OperatingSystem
if ($os) {
    Add-Result -Status INFO -Check 'Windows Version' -Detail "$($os.Caption) build $($os.BuildNumber)"
}

# GPU / driver
$gpus = Get-CimInstance Win32_VideoController
foreach ($gpu in $gpus) {
    if ($gpu.Name -match 'NVIDIA|RTX|GeForce') {
        Add-Result -Status PASS -Check 'NVIDIA GPU' -Detail "$($gpu.Name), driver $($gpu.DriverVersion)"
    } else {
        Add-Result -Status INFO -Check 'Display Adapter' -Detail "$($gpu.Name), driver $($gpu.DriverVersion)"
    }
}

# NVIDIA helper processes
$nvidiaProcesses = @('nvcontainer','nvcplui','NVIDIA App','NVIDIA Share','NVIDIA Overlay')
$runningNv = Get-Process | Where-Object {
    $_.ProcessName -match 'nvcontainer|nvcplui|NVIDIA|nvsphelper|nvdisplay'
} | Select-Object -ExpandProperty ProcessName -Unique

if ($runningNv) {
    Add-Result -Status INFO -Check 'NVIDIA Processes' -Detail ($runningNv -join ', ')
} else {
    Add-Result -Status WARN -Check 'NVIDIA Processes' -Detail 'No common NVIDIA helper processes detected.' -Recommendation 'If the NVIDIA driver is installed and working, this may be harmless.'
}

# Display information
try {
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        Add-Result -Status INFO -Check 'Display Detected' -Detail "$($screen.DeviceName) $($screen.Bounds.Width)x$($screen.Bounds.Height)"
    }
} catch {
    Add-Result -Status WARN -Check 'Display Detected' -Detail 'Could not query display through Windows Forms.'
}

# Active power plan
$powerCfg = powercfg /getactivescheme 2>$null
if ($powerCfg) {
    Add-Result -Status INFO -Check 'Active Power Plan' -Detail ($powerCfg -join ' ')
    if ($powerCfg -match 'High performance|Ultimate Performance|Bitsum Highest Performance') {
        Add-Result -Status PASS -Check 'Gaming Power Plan' -Detail 'Performance-oriented power plan appears active.'
    } else {
        Add-Result -Status WARN -Check 'Gaming Power Plan' -Detail 'Balanced or unknown power plan appears active.' -Recommendation 'For testing, use your known gaming/performance plan.'
    }
} else {
    Add-Result -Status WARN -Check 'Active Power Plan' -Detail 'Could not read active power plan.'
}

# USB selective suspend
$usbSuspend = powercfg /query SCHEME_CURRENT SUB_USB USBSELECTIVE 2>$null
if ($usbSuspend -match 'Current AC Power Setting Index:\s+0x00000000') {
    Add-Result -Status PASS -Check 'USB Selective Suspend' -Detail 'Disabled on AC power.'
} elseif ($usbSuspend -match 'Current AC Power Setting Index:\s+0x00000001') {
    Add-Result -Status WARN -Check 'USB Selective Suspend' -Detail 'Enabled on AC power.' -Recommendation 'For controller stability testing, disable USB selective suspend.'
} else {
    Add-Result -Status INFO -Check 'USB Selective Suspend' -Detail 'Could not determine AC setting.'
}

# Game Mode
$gameMode = Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
if ($null -eq $gameMode) {
    Add-Result -Status INFO -Check 'Game Mode' -Detail 'Registry value not found.'
} elseif ($gameMode -eq 1) {
    Add-Result -Status PASS -Check 'Game Mode' -Detail 'Enabled.'
} else {
    Add-Result -Status WARN -Check 'Game Mode' -Detail 'Disabled.' -Recommendation 'Usually enable Game Mode for modern Windows gaming.'
}

# Game DVR / captures
$gameDvrAppCapture = Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
$gameDvrPolicy     = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR'

if ($gameDvrAppCapture -eq 0 -or $gameDvrPolicy -eq 0) {
    Add-Result -Status PASS -Check 'Game DVR / Background Recording' -Detail 'Appears disabled or policy-disabled.'
} elseif ($gameDvrAppCapture -eq 1) {
    Add-Result -Status WARN -Check 'Game DVR / Background Recording' -Detail 'Game DVR appears enabled.' -Recommendation 'Disable background recording/captures if chasing frametime consistency.'
} else {
    Add-Result -Status INFO -Check 'Game DVR / Background Recording' -Detail 'Could not determine full state.'
}

# HAGS
$hags = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
switch ($hags) {
    2 { Add-Result -Status INFO -Check 'HAGS' -Detail 'Hardware Accelerated GPU Scheduling is enabled.' }
    1 { Add-Result -Status INFO -Check 'HAGS' -Detail 'Hardware Accelerated GPU Scheduling is disabled.' }
    default { Add-Result -Status INFO -Check 'HAGS' -Detail 'Not configured or could not determine.' }
}

# MPO
$mpo = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
if ($mpo -eq 5) {
    Add-Result -Status INFO -Check 'MPO' -Detail 'MPO appears disabled via OverlayTestMode=5.'
} elseif ($null -eq $mpo) {
    Add-Result -Status PASS -Check 'MPO' -Detail 'Default MPO behavior. No forced disable detected.'
} else {
    Add-Result -Status INFO -Check 'MPO' -Detail "OverlayTestMode=$mpo"
}

# Overlay / monitoring processes list
$processChecks = @(
    @{Name='RTSS'; Processes=@('RTSS','RTSSHooksLoader64','RTSSHooksLoader'); Needed=$true; Purpose='FPS limiter / OSD'},
    @{Name='MSI Afterburner'; Processes=@('MSIAfterburner'); Needed=$true; Purpose='GPU monitoring / fan / OSD source'},
    @{Name='CapFrameX'; Processes=@('CapFrameX'); Needed=$false; Purpose='Capture tool'},
    @{Name='PresentMon'; Processes=@('PresentMon','PresentMon_x64'); Needed=$false; Purpose='Frame telemetry'},
    @{Name='Flydigi SpaceStation'; Processes=@('FlydigiSpaceStation','Flydigi SpaceStation','FlydigiPcSpace','FlydigiPcSpaceStation'); Needed=$true; Purpose='Controller software'},
    @{Name='SteelSeries GG/Sonar'; Processes=@('SteelSeriesGG','SteelSeriesSonar','SteelSeriesEngine','SteelSeriesPrism','SteelSeriesSvc'); Needed=$true; Purpose='Audio routing'},
    @{Name='Steam'; Processes=@('steam','steamwebhelper'); Needed=$false; Purpose='Launcher / possible Steam Input'},
    @{Name='Discord'; Processes=@('Discord'); Needed=$false; Purpose='Overlay / voice'},
    @{Name='Xbox App / Game Bar'; Processes=@('XboxPcApp','GameBar','GameBarFTServer','XboxGameBarWidgets'); Needed=$false; Purpose='Overlay / captures'}
)

foreach ($check in $processChecks) {
    $found = @()
    foreach ($pname in $check.Processes) {
        $p = Get-Process -Name $pname -ErrorAction SilentlyContinue
        if ($p) {
            $found += $p.ProcessName
        }
    }

    $found = $found | Select-Object -Unique

    if ($found.Count -gt 0) {
        Add-Result -Status INFO -Check $check.Name -Detail ("Running: {0} ({1})" -f ($found -join ', '), $check.Purpose)
    } elseif ($check.Needed) {
        Add-Result -Status WARN -Check $check.Name -Detail "Not detected running. $($check.Purpose)." -Recommendation 'Start it before launching Halo if you rely on it.'
    } else {
        Add-Result -Status PASS -Check $check.Name -Detail "Not running. $($check.Purpose)."
    }
}

# Limiter conflict hints
$rtssRunning = Test-ProcessRunning @('RTSS')
$capFrameXRunning = Test-ProcessRunning @('CapFrameX')
$presentMonRunning = Test-ProcessRunning @('PresentMon','PresentMon_x64')
$gameBarRunning = Test-ProcessRunning @('GameBar','GameBarFTServer','XboxGameBarWidgets')
$discordRunning = Test-ProcessRunning @('Discord')
$steamRunning = Test-ProcessRunning @('steam')

if ($rtssRunning) {
    Add-Result -Status PASS -Check 'FPS Limiter Source' -Detail 'RTSS is running and can be your single limiter source.' -Recommendation 'For 240 Hz VRR, start with RTSS 237 FPS cap.'
} else {
    Add-Result -Status WARN -Check 'FPS Limiter Source' -Detail 'RTSS is not running.' -Recommendation 'Use either RTSS, in-game cap, or NVCP cap. Do not stack multiple caps.'
}

if ($capFrameXRunning -and $presentMonRunning) {
    Add-Result -Status WARN -Check 'Telemetry Overlap' -Detail 'CapFrameX and PresentMon both appear running.' -Recommendation 'For clean capture, avoid duplicate telemetry tools unless intentionally testing.'
} else {
    Add-Result -Status PASS -Check 'Telemetry Overlap' -Detail 'No obvious CapFrameX + PresentMon overlap detected.'
}

if ($gameBarRunning -or $discordRunning) {
    Add-Result -Status WARN -Check 'Overlay Overlap' -Detail 'Game Bar and/or Discord overlay-related processes are running.' -Recommendation 'Disable unnecessary overlays during latency/frametime testing.'
} else {
    Add-Result -Status PASS -Check 'Overlay Overlap' -Detail 'No obvious Game Bar or Discord overlay process detected.'
}

if ($steamRunning) {
    Add-Result -Status WARN -Check 'Steam Input Check' -Detail 'Steam is running.' -Recommendation 'For Flydigi native input, confirm Steam Input is disabled for Halo unless you intentionally use it.'
} else {
    Add-Result -Status PASS -Check 'Steam Input Check' -Detail 'Steam is not running, so Steam Input conflict is unlikely.'
}

# Halo process/path detection
$haloProcesses = Get-Process | Where-Object {
    $_.ProcessName -match 'HaloInfinite|Halo|game'
}

if ($haloProcesses) {
    foreach ($hp in $haloProcesses) {
        Add-Result -Status INFO -Check 'Halo Process' -Detail "Detected process: $($hp.ProcessName), PID $($hp.Id)"
    }
} else {
    Add-Result -Status INFO -Check 'Halo Process' -Detail 'Halo does not appear to be running right now.'
}

# Services relevant to controller/audio/vendor utilities
$serviceNames = @(
    'SteelSeriesSvc',
    'NahimicService',
    'GameInputSvc',
    'XboxGipSvc',
    'XblAuthManager',
    'XblGameSave',
    'BthAvctpSvc',
    'Audiosrv',
    'AudioEndpointBuilder'
)

foreach ($svcName in $serviceNames) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq 'Running') {
            Add-Result -Status PASS -Check "Service: $svcName" -Detail "Running, startup type: $($svc.StartType)"
        } else {
            Add-Result -Status WARN -Check "Service: $svcName" -Detail "Status: $($svc.Status), startup type: $($svc.StartType)" -Recommendation 'Only change if you know this service is part of your actual input/audio path.'
        }
    }
}

# Audio devices
try {
    $audioDevices = Get-CimInstance Win32_SoundDevice
    foreach ($dev in $audioDevices) {
        Add-Result -Status INFO -Check 'Audio Device' -Detail "$($dev.Name) - $($dev.Status)"
    }
} catch {
    Add-Result -Status WARN -Check 'Audio Device' -Detail 'Could not query sound devices.'
}

# Network adapters
$netAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up'
foreach ($nic in $netAdapters) {
    Add-Result -Status INFO -Check 'Active Network Adapter' -Detail "$($nic.Name) - $($nic.InterfaceDescription) - LinkSpeed $($nic.LinkSpeed)"
}

# Recent critical system/app events (last 24 hours)
$since = (Get-Date).AddHours(-24)
$eventFilters = @(
    @{LogName='System'; Level=1,2; StartTime=$since},
    @{LogName='Application'; Level=1,2; StartTime=$since}
)

foreach ($filter in $eventFilters) {
    $events = Get-WinEvent -FilterHashtable $filter -MaxEvents 20 -ErrorAction SilentlyContinue
    if ($events) {
        Add-Result -Status WARN -Check "Recent $($filter.LogName) Errors" -Detail "$($events.Count) critical/error events found in last 24 hours." -Recommendation 'Open Event Viewer or inspect the saved report details.'
        foreach ($e in $events | Select-Object -First 8) {
            $msg = ($e.Message -replace "`r|`n", ' ')
            if ($msg.Length -gt 180) {
                $msg = $msg.Substring(0,180) + '...'
            }
            Add-Result -Status INFO -Check "Event $($e.Id)" -Detail "$($e.TimeCreated) - $($e.ProviderName) - $msg"
        }
    } else {
        Add-Result -Status PASS -Check "Recent $($filter.LogName) Errors" -Detail 'No critical/error events found in last 24 hours.'
    }
}

# Summary classification
$warnCount = ($Results | Where-Object Status -eq 'WARN').Count
$actionCount = ($Results | Where-Object Status -eq 'ACTION').Count

if ($actionCount -gt 0) {
    Add-Result -Status ACTION -Check 'Overall Halo Readiness' -Detail "$actionCount action item(s), $warnCount warning(s)." -Recommendation 'Fix ACTION items first, then retest.'
} elseif ($warnCount -gt 0) {
    Add-Result -Status WARN -Check 'Overall Halo Readiness' -Detail "$warnCount warning(s) found." -Recommendation 'Good enough to play, but clean warnings before serious telemetry.'
} else {
    Add-Result -Status PASS -Check 'Overall Halo Readiness' -Detail 'No major issues detected.'
}

# Save reports
$header = @"
GPTOPT Halo Preflight Audit
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Time: $(Get-Date)
Admin: $isAdmin

"@

$body = $Results | Format-Table -AutoSize | Out-String -Width 240
$details = $Results | Format-List | Out-String -Width 240

Set-Content -Path $ReportPath -Value ($header + $body + "`r`nDETAILS`r`n" + $details) -Encoding UTF8
$Results | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonPath -Encoding UTF8

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DONE - Halo preflight audit complete.' -ForegroundColor Cyan
Write-Host "TXT report:  $ReportPath" -ForegroundColor Cyan
Write-Host "JSON report: $JsonPath" -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
