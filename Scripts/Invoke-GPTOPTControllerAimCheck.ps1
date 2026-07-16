#requires -Version 5.1
<#
.SYNOPSIS
    Read-only GPTOPT controller and aim-feel diagnostic for XInput controllers.

.DESCRIPTION
    Measures neutral-stick centering/noise, guided stick range, XInput update
    intervals during motion, controller/remapper conflicts, Flydigi runtime
    state, USB selective suspend, and Halo controller-setting visibility.
    It never changes Windows, Flydigi, Steam, or Halo settings.
#>
[CmdletBinding()]
param(
    [ValidateRange(0,3)]
    [int]$ControllerIndex = 0,
    [ValidateRange(3,15)]
    [int]$CenterSeconds = 5,
    [ValidateRange(8,30)]
    [int]$MovementSeconds = 15,
    [string]$OutputRoot = (Join-Path $(if($env:USERPROFILE){$env:USERPROFILE}else{[IO.Path]::GetTempPath()}) 'Desktop\GPTOPT-Logs\ControllerAim'),
    [string]$Repository = 'ShellPower2003/GPTOPT-Gaming-Assistant',
    [switch]$Publish,
    [switch]$NoPause,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

function Set-GPTOPTProgress {
    param([int]$Percent,[string]$Stage)
    Write-Progress -Activity 'GPTOPT Controller Aim Check' -Status ("{0}% - {1}" -f $Percent,$Stage) -PercentComplete $Percent
}

function Get-Percentile {
    param([double[]]$Values,[ValidateRange(0,100)][double]$Percentile)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $position = ($Percentile / 100) * ($sorted.Count - 1)
    $lower = [math]::Floor($position)
    $upper = [math]::Ceiling($position)
    if ($lower -eq $upper) { return [double]$sorted[$lower] }
    $weight = $position - $lower
    return ([double]$sorted[$lower] * (1 - $weight)) + ([double]$sorted[$upper] * $weight)
}

function Get-AxisSummary {
    param([object[]]$Samples,[string]$Name)
    $values = [double[]]@($Samples | ForEach-Object { [double]$_.$Name })
    $mean = ($values | Measure-Object -Average).Average
    $variance = (($values | ForEach-Object { [math]::Pow($_ - $mean,2) }) | Measure-Object -Average).Average
    [pscustomobject]@{
        mean_pct = [math]::Round($mean * 100,3)
        noise_stddev_pct = [math]::Round([math]::Sqrt($variance) * 100,3)
        min_pct = [math]::Round((($values | Measure-Object -Minimum).Minimum) * 100,2)
        max_pct = [math]::Round((($values | Measure-Object -Maximum).Maximum) * 100,2)
    }
}

function Convert-XInputAxis {
    param([int16]$Value)
    if ($Value -lt 0) { return [double]$Value / 32768.0 }
    return [double]$Value / 32767.0
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$List,
        [ValidateSet('PASS','CHECK','FAIL','INFO')][string]$Status,
        [string]$Area,
        [string]$Detail
    )
    $List.Add([pscustomobject]@{ status=$Status; area=$Area; detail=$Detail }) | Out-Null
}

function Get-FlatJsonMap {
    param([string]$Path)
    $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $map = [ordered]@{}
    foreach ($property in $json.PSObject.Properties) {
        $item = $property.Value
        $value = $null
        if ($null -eq $item -or $item -is [string] -or $item -is [ValueType]) {
            $value = $item
        } else {
            foreach ($leaf in 'value','Value','current','Current','data','Data','setting','Setting') {
                if ($item.PSObject.Properties.Name -contains $leaf) { $value = $item.$leaf; break }
            }
        }
        if ($null -ne $value) { $map[$property.Name] = [string]$value }
    }
    return $map
}

function Publish-GPTOPTControllerReport {
    param([string]$Repo,[string]$Body)
    $gh = Get-Command gh.exe -ErrorAction SilentlyContinue
    if (-not $gh) { $gh = Get-Command gh -ErrorAction SilentlyContinue }
    if (-not $gh) { throw 'GitHub CLI was not found. Run the GPTOPT bootstrap or install gh.' }

    & $gh.Source auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated. Run: gh auth login' }

    $title = '[GPTOPT-CONTROLLER] Latest Controller Aim Report'
    $searchJson = & $gh.Source issue list --repo $Repo --state open --search '"[GPTOPT-CONTROLLER]" in:title' --json number,title --limit 20
    if ($LASTEXITCODE -ne 0) { throw 'Unable to query the persistent controller report issue.' }
    $existing = @($searchJson | ConvertFrom-Json) | Where-Object title -eq $title | Select-Object -First 1
    $temp = Join-Path $env:TEMP ("gptopt-controller-{0}.md" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $temp -Value $Body -Encoding UTF8
        if ($existing) {
            & $gh.Source issue edit $existing.number --repo $Repo --body-file $temp
            if ($LASTEXITCODE -ne 0) { throw 'Unable to update the persistent controller report issue.' }
            return (& $gh.Source issue view $existing.number --repo $Repo --json url --jq .url)
        }
        $url = & $gh.Source issue create --repo $Repo --title $title --body-file $temp
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create the persistent controller report issue.' }
        return $url
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

Set-GPTOPTProgress 3 'Loading native XInput reader'
if (-not ('GPTOPT.XInput' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace GPTOPT {
    [StructLayout(LayoutKind.Sequential)]
    public struct XInputGamepad {
        public ushort Buttons;
        public byte LeftTrigger;
        public byte RightTrigger;
        public short ThumbLX;
        public short ThumbLY;
        public short ThumbRX;
        public short ThumbRY;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XInputState {
        public uint PacketNumber;
        public XInputGamepad Gamepad;
    }

    public static class XInput {
        [DllImport("xinput1_4.dll", EntryPoint="XInputGetState")]
        private static extern uint GetState14(uint userIndex, out XInputState state);

        [DllImport("xinput9_1_0.dll", EntryPoint="XInputGetState")]
        private static extern uint GetState910(uint userIndex, out XInputState state);

        public static uint GetState(uint userIndex, out XInputState state) {
            try { return GetState14(userIndex, out state); }
            catch (DllNotFoundException) { return GetState910(userIndex, out state); }
            catch (EntryPointNotFoundException) { return GetState910(userIndex, out state); }
        }
    }
}
'@
}

if ($SelfTest) {
    $list = New-Object System.Collections.Generic.List[object]
    $list.Add([pscustomobject]@{ packet=1; lx=0.0; ly=0.0; rx=0.0; ry=0.0 }) | Out-Null
    $converted = $list.ToArray()
    if ($converted.Count -ne 1 -or $converted[0].packet -ne 1) { throw 'Controller sample-list self-test failed.' }
    Write-Host 'PASS: controller diagnostic backend loads.' -ForegroundColor Green
    Write-Host 'PASS: embedded XInput reader compiles.' -ForegroundColor Green
    Write-Host 'PASS: PowerShell sample-list conversion works.' -ForegroundColor Green
    return
}

function Read-XInputState {
    param([int]$Index)
    $state = New-Object GPTOPT.XInputState
    $result = [GPTOPT.XInput]::GetState([uint32]$Index,[ref]$state)
    if ($result -ne 0) { return $null }
    [pscustomobject]@{
        packet = [uint32]$state.PacketNumber
        lx = Convert-XInputAxis $state.Gamepad.ThumbLX
        ly = Convert-XInputAxis $state.Gamepad.ThumbLY
        rx = Convert-XInputAxis $state.Gamepad.ThumbRX
        ry = Convert-XInputAxis $state.Gamepad.ThumbRY
        lt = [math]::Round($state.Gamepad.LeftTrigger / 255.0,4)
        rt = [math]::Round($state.Gamepad.RightTrigger / 255.0,4)
        buttons = [uint16]$state.Gamepad.Buttons
    }
}

function Collect-XInputSamples {
    param([int]$Index,[int]$Seconds,[string]$Stage,[int]$StartPercent,[int]$EndPercent)
    $samples = New-Object System.Collections.Generic.List[object]
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $Seconds) {
        $state = Read-XInputState $Index
        if ($null -eq $state) { throw "Controller disconnected from XInput slot $Index during $Stage." }
        $samples.Add([pscustomobject]@{
            ms = [math]::Round($clock.Elapsed.TotalMilliseconds,3)
            packet = $state.packet
            lx = $state.lx; ly = $state.ly; rx = $state.rx; ry = $state.ry
            lt = $state.lt; rt = $state.rt; buttons = $state.buttons
        }) | Out-Null
        $fraction = [math]::Min(1,$clock.Elapsed.TotalSeconds / $Seconds)
        $percent = [int]($StartPercent + (($EndPercent - $StartPercent) * $fraction))
        Write-Progress -Activity 'GPTOPT Controller Aim Check' -Status ("{0}% - {1}: {2:N1}s / {3}s" -f $percent,$Stage,$clock.Elapsed.TotalSeconds,$Seconds) -PercentComplete $percent
        [Threading.Thread]::Sleep(1)
    }
    $clock.Stop()
    # PowerShell 7.5+ can throw "Argument types do not match" when @(...)
    # wraps a generic List[object]. ToArray() is stable in Windows PowerShell
    # 5.1 and current PowerShell 7 releases.
    return $samples.ToArray()
}

Write-Host ''
Write-Host '=== GPTOPT CONTROLLER AIM CHECK ===' -ForegroundColor Cyan
Write-Host 'READ-ONLY: no Windows, Flydigi, Steam, or Halo settings will be changed.' -ForegroundColor Green
Write-Host 'Keep the Vader 4 Pro WIRED and keep Flydigi SpaceStation running.' -ForegroundColor Yellow
Write-Host ''

Set-GPTOPTProgress 8 'Detecting connected XInput slots'
$connectedSlots = @()
foreach ($slot in 0..3) { if ($null -ne (Read-XInputState $slot)) { $connectedSlots += $slot } }
if ($connectedSlots.Count -eq 0) { throw 'No XInput controller detected. Connect the Vader 4 Pro by USB in XInput mode and retry.' }
if ($connectedSlots -notcontains $ControllerIndex) {
    if ($PSBoundParameters.ContainsKey('ControllerIndex')) { throw "XInput slot $ControllerIndex is not connected. Connected slot(s): $($connectedSlots -join ', ')." }
    $ControllerIndex = $connectedSlots[0]
}
Write-Host "Using XInput slot $ControllerIndex. Connected slot(s): $($connectedSlots -join ', ')" -ForegroundColor Cyan

Set-GPTOPTProgress 12 'Collecting controller and software inventory'
$allPnp = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue)
$controllerPnp = @($allPnp | Where-Object {
    $_.FriendlyName -match 'Flydigi|Vader|Xbox|XInput|Game Controller|HID-compliant game' -or
    $_.InstanceId -match 'VID_045E&PID_028E|FLYDIGI_VADER4'
} | Select-Object Class,FriendlyName,Status,InstanceId)

$processNames = @('FlydigiSpaceStation','GameControllerService','steam','steamwebhelper','reWASD','reWASDEngine','DS4Windows','HidHideClient','HandheldCompanion')
$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $processNames -contains $_.ProcessName } |
    Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)
$serviceRows = @('GameInputSvc','XboxGipSvc','hidserv') | ForEach-Object {
    $service = Get-Service -Name $_ -ErrorAction SilentlyContinue
    if ($service) { [pscustomobject]@{ name=$service.Name; status=[string]$service.Status; start_type=[string]$service.StartType } }
}
$usbQuery = (powercfg.exe /query SCHEME_CURRENT SUB_USB USBSELECTIVE 2>$null | Out-String)
$usbSelectiveSuspend = if ($usbQuery -match 'Current AC Power Setting Index:\s+0x00000000') { 'Disabled' } elseif ($usbQuery -match 'Current AC Power Setting Index:\s+0x00000001') { 'Enabled' } else { 'Unknown' }

$flydigiRoots = @(
    (Join-Path $env:APPDATA 'Flydigi'),
    (Join-Path $env:LOCALAPPDATA 'Flydigi'),
    (Join-Path $env:APPDATA 'FlydigiSpaceStation'),
    (Join-Path $env:LOCALAPPDATA 'FlydigiSpaceStation')
)
$flydigiLocations = @($flydigiRoots | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
    $item = Get-Item -LiteralPath $_
    [pscustomobject]@{ path=$item.FullName; last_write=$item.LastWriteTime.ToString('s') }
})

$haloPath = Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings\SpecControlSettings.json'
$haloControllerSettings = [ordered]@{}
if (Test-Path -LiteralPath $haloPath) {
    try {
        $haloMap = Get-FlatJsonMap $haloPath
        foreach ($key in $haloMap.Keys) {
            if ($key -match 'controller|dead.?zone|sensitivity|accel|look|aim|zoom') { $haloControllerSettings[$key] = $haloMap[$key] }
        }
    } catch { $haloControllerSettings['read_error'] = $_.Exception.Message }
}

Set-GPTOPTProgress 18 'Preparing neutral-stick measurement'
Write-Host ''
Write-Host "CENTER TEST: Put the controller flat and take BOTH thumbs completely off the sticks." -ForegroundColor Yellow
foreach ($second in 3..1) { Write-Host "Starting in $second..." -ForegroundColor DarkYellow; Start-Sleep -Seconds 1 }
$centerSamples = Collect-XInputSamples -Index $ControllerIndex -Seconds $CenterSeconds -Stage 'Hands-off center test' -StartPercent 20 -EndPercent 45

Set-GPTOPTProgress 47 'Preparing movement and range measurement'
Write-Host ''
Write-Host "MOVEMENT TEST ($MovementSeconds seconds):" -ForegroundColor Yellow
Write-Host '1. Rotate BOTH sticks slowly around their full outside edge twice.' -ForegroundColor Yellow
Write-Host '2. Then flick each stick fully left/right/up/down several times.' -ForegroundColor Yellow
Write-Host '3. Keep moving until the timer finishes.' -ForegroundColor Yellow
foreach ($second in 4..1) { Write-Host "Starting in $second..." -ForegroundColor DarkYellow; Start-Sleep -Seconds 1 }
$movementSamples = Collect-XInputSamples -Index $ControllerIndex -Seconds $MovementSeconds -Stage 'Full-range movement test' -StartPercent 50 -EndPercent 78

Set-GPTOPTProgress 80 'Analyzing stick center, noise, range, and updates'
$centerLX = Get-AxisSummary $centerSamples 'lx'
$centerLY = Get-AxisSummary $centerSamples 'ly'
$centerRX = Get-AxisSummary $centerSamples 'rx'
$centerRY = Get-AxisSummary $centerSamples 'ry'
$leftCenterRadius = [double[]]@($centerSamples | ForEach-Object { [math]::Sqrt(($_.lx * $_.lx) + ($_.ly * $_.ly)) * 100 })
$rightCenterRadius = [double[]]@($centerSamples | ForEach-Object { [math]::Sqrt(($_.rx * $_.rx) + ($_.ry * $_.ry)) * 100 })

$range = [ordered]@{}
foreach ($axis in 'lx','ly','rx','ry') {
    $values = [double[]]@($movementSamples | ForEach-Object { [double]$_.$axis })
    $minimum = ($values | Measure-Object -Minimum).Minimum
    $maximum = ($values | Measure-Object -Maximum).Maximum
    $range[$axis] = [pscustomobject]@{
        negative_pct = [math]::Round([math]::Abs([math]::Min(0,$minimum)) * 100,2)
        positive_pct = [math]::Round([math]::Max(0,$maximum) * 100,2)
    }
}

$packetTimes = New-Object System.Collections.Generic.List[double]
$lastPacket = $null
foreach ($sample in $movementSamples) {
    if ($null -eq $lastPacket -or $sample.packet -ne $lastPacket) { $packetTimes.Add([double]$sample.ms) | Out-Null; $lastPacket = $sample.packet }
}
$updateIntervals = @()
for ($i=1; $i -lt $packetTimes.Count; $i++) { $updateIntervals += ($packetTimes[$i] - $packetTimes[$i-1]) }
$medianUpdateMs = Get-Percentile ([double[]]$updateIntervals) 50
$p95UpdateMs = Get-Percentile ([double[]]$updateIntervals) 95
$observedHz = if ($medianUpdateMs -and $medianUpdateMs -gt 0) { [math]::Round(1000 / $medianUpdateMs,1) } else { $null }

$leftPerimeter = [double[]]@($movementSamples | ForEach-Object { [math]::Sqrt(($_.lx * $_.lx) + ($_.ly * $_.ly)) } | Where-Object { $_ -ge 0.75 })
$rightPerimeter = [double[]]@($movementSamples | ForEach-Object { [math]::Sqrt(($_.rx * $_.rx) + ($_.ry * $_.ry)) } | Where-Object { $_ -ge 0.75 })

$analysis = [pscustomobject]@{
    center = [pscustomobject]@{
        left_radius_mean_pct = [math]::Round((($leftCenterRadius | Measure-Object -Average).Average),3)
        left_radius_p95_pct = [math]::Round((Get-Percentile $leftCenterRadius 95),3)
        left_radius_max_pct = [math]::Round((($leftCenterRadius | Measure-Object -Maximum).Maximum),3)
        right_radius_mean_pct = [math]::Round((($rightCenterRadius | Measure-Object -Average).Average),3)
        right_radius_p95_pct = [math]::Round((Get-Percentile $rightCenterRadius 95),3)
        right_radius_max_pct = [math]::Round((($rightCenterRadius | Measure-Object -Maximum).Maximum),3)
        axes = [pscustomobject]@{ lx=$centerLX; ly=$centerLY; rx=$centerRX; ry=$centerRY }
    }
    range = [pscustomobject]$range
    perimeter = [pscustomobject]@{
        left_sample_count = $leftPerimeter.Count
        left_radius_median_pct = if($leftPerimeter.Count){[math]::Round((Get-Percentile $leftPerimeter 50)*100,2)}else{$null}
        right_sample_count = $rightPerimeter.Count
        right_radius_median_pct = if($rightPerimeter.Count){[math]::Round((Get-Percentile $rightPerimeter 50)*100,2)}else{$null}
    }
    xinput_motion_updates = [pscustomobject]@{
        changed_packets = $packetTimes.Count
        median_interval_ms = if($medianUpdateMs){[math]::Round($medianUpdateMs,3)}else{$null}
        p95_interval_ms = if($p95UpdateMs){[math]::Round($p95UpdateMs,3)}else{$null}
        observed_change_hz = $observedHz
        note = 'Movement-dependent XInput packet timing; this is not a direct USB polling-rate certification.'
    }
}

$findings = New-Object System.Collections.Generic.List[object]
Add-Finding $findings 'INFO' 'Safety' 'Read-only collection completed; no settings were changed.'
if ($runningProcesses -contains 'FlydigiSpaceStation' -or $runningProcesses -contains 'GameControllerService') {
    Add-Finding $findings 'PASS' 'Flydigi runtime' ("Detected: {0}" -f (($runningProcesses | Where-Object { $_ -match 'Flydigi|GameControllerService' }) -join ', '))
} else { Add-Finding $findings 'FAIL' 'Flydigi runtime' 'Flydigi SpaceStation/GameControllerService was not detected. Your required controller processing path may not be active.' }

if ($connectedSlots.Count -eq 1) { Add-Finding $findings 'PASS' 'XInput devices' 'Exactly one XInput controller is connected.' }
else { Add-Finding $findings 'CHECK' 'XInput devices' ("$($connectedSlots.Count) controllers are connected in slots $($connectedSlots -join ', '); confirm Halo is using the intended device.") }

$remappers = @($runningProcesses | Where-Object { $_ -match 'reWASD|DS4Windows|HidHide|HandheldCompanion' })
if ($remappers.Count -eq 0) { Add-Finding $findings 'PASS' 'Remapper conflict' 'No common third-party controller remapper process was detected.' }
else { Add-Finding $findings 'FAIL' 'Remapper conflict' ("Possible competing input layer detected: $($remappers -join ', ').") }

if ($runningProcesses -contains 'steam') { Add-Finding $findings 'CHECK' 'Steam Input' 'Steam is running. Process inspection cannot prove Halo per-game Steam Input state; verify it is Disabled unless intentionally used.' }
else { Add-Finding $findings 'INFO' 'Steam Input' 'Steam was not running during the test.' }

if ($usbSelectiveSuspend -eq 'Disabled') { Add-Finding $findings 'PASS' 'USB selective suspend' 'Disabled on AC power.' }
elseif ($usbSelectiveSuspend -eq 'Enabled') { Add-Finding $findings 'CHECK' 'USB selective suspend' 'Enabled on AC power; this can be tested later if disconnects or inconsistent input timing occur.' }
else { Add-Finding $findings 'INFO' 'USB selective suspend' 'State could not be determined.' }

$leftP95 = [double]$analysis.center.left_radius_p95_pct
$rightP95 = [double]$analysis.center.right_radius_p95_pct
if ($leftP95 -le 0.5) { Add-Finding $findings 'PASS' 'Left-stick center' ("Hands-off p95 radius: $leftP95%.") }
elseif ($leftP95 -le 1.5) { Add-Finding $findings 'CHECK' 'Left-stick center' ("Hands-off p95 radius: $leftP95%; small offset/noise may matter with a very low deadzone.") }
else { Add-Finding $findings 'FAIL' 'Left-stick center' ("Hands-off p95 radius: $leftP95%; likely calibration, drift, or deadzone issue.") }
if ($rightP95 -le 0.5) { Add-Finding $findings 'PASS' 'Right-stick center' ("Hands-off p95 radius: $rightP95%.") }
elseif ($rightP95 -le 1.5) { Add-Finding $findings 'CHECK' 'Right-stick center' ("Hands-off p95 radius: $rightP95%; this can directly affect micro-aim with a very low look deadzone.") }
else { Add-Finding $findings 'FAIL' 'Right-stick center' ("Hands-off p95 radius: $rightP95%; likely calibration, drift, or deadzone issue affecting aim.") }

foreach ($stick in @(@{name='Left';axes=@('lx','ly')},@{name='Right';axes=@('rx','ry')})) {
    $coverage = @()
    foreach ($axis in $stick.axes) { $coverage += [double]$analysis.range.$axis.negative_pct; $coverage += [double]$analysis.range.$axis.positive_pct }
    $minimumCoverage = ($coverage | Measure-Object -Minimum).Minimum
    if ($minimumCoverage -ge 95) { Add-Finding $findings 'PASS' "$($stick.name)-stick range" ("All four directions reached at least $([math]::Round($minimumCoverage,1))%.") }
    elseif ($minimumCoverage -ge 90) { Add-Finding $findings 'CHECK' "$($stick.name)-stick range" ("Weakest direction reached $([math]::Round($minimumCoverage,1))%. Repeat once with firm cardinal flicks before blaming calibration.") }
    else { Add-Finding $findings 'FAIL' "$($stick.name)-stick range" ("Weakest direction reached only $([math]::Round($minimumCoverage,1))%; recalibration or a restricted Flydigi range may be involved.") }
}

if ($packetTimes.Count -lt 50) { Add-Finding $findings 'CHECK' 'XInput updates' 'Too few changing packets were observed. Repeat and keep both sticks moving continuously.' }
elseif ($p95UpdateMs -gt 12) { Add-Finding $findings 'CHECK' 'XInput updates' ("Motion packet p95 interval was $([math]::Round($p95UpdateMs,2)) ms. This can reflect uneven hand movement, so confirm with a dedicated polling tester before changing USB settings.") }
else { Add-Finding $findings 'PASS' 'XInput updates' ("Motion produced $($packetTimes.Count) changing packets; median $([math]::Round($medianUpdateMs,2)) ms, p95 $([math]::Round($p95UpdateMs,2)) ms.") }

if ($haloControllerSettings.Count -eq 0) { Add-Finding $findings 'CHECK' 'Halo controller settings' 'No controller-related scalar settings were readable from SpecControlSettings.json. In-game values still need a UI screenshot or manual confirmation.' }
else { Add-Finding $findings 'INFO' 'Halo controller settings' ("Captured $($haloControllerSettings.Count) controller/aim-related values from the local Halo config without editing it.") }

Set-GPTOPTProgress 90 'Writing local diagnostic report'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runDirectory = Join-Path $OutputRoot "GPTOPT-ControllerAim-$stamp"
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$report = [pscustomobject]@{
    schema_version = 1
    collector_version = '1.0.0'
    collected_local = (Get-Date).ToString('o')
    read_only = $true
    controller_index = $ControllerIndex
    connected_xinput_slots = $connectedSlots
    sample_counts = [pscustomobject]@{ center=$centerSamples.Count; movement=$movementSamples.Count }
    runtime = [pscustomobject]@{
        processes = $runningProcesses
        services = @($serviceRows)
        usb_selective_suspend_ac = $usbSelectiveSuspend
        flydigi_locations = $flydigiLocations
    }
    devices = $controllerPnp
    halo = [pscustomobject]@{ settings_path_found=(Test-Path -LiteralPath $haloPath); controller_settings=[pscustomobject]$haloControllerSettings }
    measurements = $analysis
    findings = @($findings)
}

$jsonPath = Join-Path $runDirectory 'GPTOPT-ControllerAim-Report.json'
$markdownPath = Join-Path $runDirectory 'GPTOPT-ControllerAim-Report.md'
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add('# GPTOPT Controller Aim Report')
$markdown.Add('')
$markdown.Add('> Read-only diagnostic. No Windows, Flydigi, Steam, or Halo settings were changed.')
$markdown.Add('')
$markdown.Add("- Collected: $($report.collected_local)")
$markdown.Add("- XInput slot: $ControllerIndex")
$markdown.Add("- Connected slots: $($connectedSlots -join ', ')")
$markdown.Add("- Center samples: $($centerSamples.Count)")
$markdown.Add("- Movement samples: $($movementSamples.Count)")
$markdown.Add('')
$markdown.Add('## Bottom line')
foreach ($finding in $findings) { $markdown.Add("- **$($finding.status) - $($finding.area):** $($finding.detail)") }
$markdown.Add('')
$markdown.Add('## Stick measurements')
$markdown.Add("- Left center radius: mean $($analysis.center.left_radius_mean_pct)%, p95 $($analysis.center.left_radius_p95_pct)%, max $($analysis.center.left_radius_max_pct)%")
$markdown.Add("- Right center radius: mean $($analysis.center.right_radius_mean_pct)%, p95 $($analysis.center.right_radius_p95_pct)%, max $($analysis.center.right_radius_max_pct)%")
$markdown.Add("- Left axes: LX mean $($analysis.center.axes.lx.mean_pct)%, noise $($analysis.center.axes.lx.noise_stddev_pct)%; LY mean $($analysis.center.axes.ly.mean_pct)%, noise $($analysis.center.axes.ly.noise_stddev_pct)%")
$markdown.Add("- Right axes: RX mean $($analysis.center.axes.rx.mean_pct)%, noise $($analysis.center.axes.rx.noise_stddev_pct)%; RY mean $($analysis.center.axes.ry.mean_pct)%, noise $($analysis.center.axes.ry.noise_stddev_pct)%")
$markdown.Add("- Left range: X -$($analysis.range.lx.negative_pct)% / +$($analysis.range.lx.positive_pct)%; Y -$($analysis.range.ly.negative_pct)% / +$($analysis.range.ly.positive_pct)%")
$markdown.Add("- Right range: X -$($analysis.range.rx.negative_pct)% / +$($analysis.range.rx.positive_pct)%; Y -$($analysis.range.ry.negative_pct)% / +$($analysis.range.ry.positive_pct)%")
$markdown.Add("- XInput motion updates: $($analysis.xinput_motion_updates.changed_packets) changed packets; median $($analysis.xinput_motion_updates.median_interval_ms) ms; p95 $($analysis.xinput_motion_updates.p95_interval_ms) ms; observed-change rate $($analysis.xinput_motion_updates.observed_change_hz) Hz")
$markdown.Add("- Timing note: $($analysis.xinput_motion_updates.note)")
$markdown.Add('')
$markdown.Add('## Runtime state')
$markdown.Add("- Processes: $(if($runningProcesses){$runningProcesses -join ', '}else{'None of the tracked processes detected'})")
$markdown.Add("- USB selective suspend on AC: $usbSelectiveSuspend")
$markdown.Add("- Halo controller values captured: $($haloControllerSettings.Count)")
$markdown.Add('')
$markdown.Add('## Halo controller values')
if ($haloControllerSettings.Count -gt 0) {
    foreach ($key in $haloControllerSettings.Keys) { $markdown.Add("- ``$key``: $($haloControllerSettings[$key])") }
} else {
    $markdown.Add('- No controller-related scalar values were readable from the Halo JSON file.')
}
$markdown.Add('')
$markdown.Add('This issue is automatically replaced by the next controller test so GPTOPT always has the latest result.')
$markdown -join "`r`n" | Set-Content -LiteralPath $markdownPath -Encoding UTF8

$latestDirectory = Join-Path $OutputRoot 'latest'
New-Item -ItemType Directory -Path $latestDirectory -Force | Out-Null
Copy-Item -LiteralPath $jsonPath,$markdownPath -Destination $latestDirectory -Force

$publishResult = 'not requested'
if ($Publish) {
    Set-GPTOPTProgress 96 'Uploading latest controller report to GitHub'
    try {
        $publishResult = Publish-GPTOPTControllerReport -Repo $Repository -Body ($markdown -join "`r`n")
        Add-Finding $findings 'PASS' 'Automatic upload' "Published latest controller result: $publishResult"
    } catch {
        $publishResult = "FAILED: $($_.Exception.Message)"
        Add-Finding $findings 'FAIL' 'Automatic upload' $publishResult
    }
}

Set-GPTOPTProgress 100 'Complete'
Write-Progress -Activity 'GPTOPT Controller Aim Check' -Completed
Write-Host ''
Write-Host 'GPTOPT CONTROLLER AIM CHECK 100% COMPLETE' -ForegroundColor Green
foreach ($finding in $findings) {
    $color = switch ($finding.status) { 'PASS' {'Green'} 'FAIL' {'Red'} 'CHECK' {'Yellow'} default {'Cyan'} }
    Write-Host ("[{0}] {1}: {2}" -f $finding.status,$finding.area,$finding.detail) -ForegroundColor $color
}
Write-Host ''
Write-Host "REPORT: $markdownPath" -ForegroundColor Cyan
Write-Host "JSON:   $jsonPath" -ForegroundColor Cyan
Write-Host "UPLOAD: $publishResult" -ForegroundColor $(if($publishResult -like 'http*'){'Green'}else{'Yellow'})
Start-Process explorer.exe $runDirectory
if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
