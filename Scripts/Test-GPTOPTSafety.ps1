[CmdletBinding()]
param(
    [ValidateSet('NormalGaming', 'BenchmarkCapture', 'HaloTroubleshooting', 'FullOptimizationPreview')]
    [string]$Context = 'NormalGaming',

    [switch]$AsObject,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Get-RegistryValue {
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

function Get-FirstCimInstance {
    param(
        [string]$ClassName,
        [string]$Filter = '',
        [string]$Namespace = ''
    )

    try {
        $arguments = @{
            ClassName = $ClassName
            ErrorAction = 'Stop'
        }
        if ($Filter) { $arguments.Filter = $Filter }
        if ($Namespace) { $arguments.Namespace = $Namespace }
        return Get-CimInstance @arguments | Select-Object -First 1
    } catch {
        return $null
    }
}

function Get-AllCimInstances {
    param([string]$ClassName)

    try {
        return @(Get-CimInstance -ClassName $ClassName -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Get-SecureBootState {
    try {
        return [string](Confirm-SecureBootUEFI -ErrorAction Stop)
    } catch {
        return 'Unavailable'
    }
}

function Get-VbsState {
    $deviceGuard = Get-FirstCimInstance -ClassName 'Win32_DeviceGuard' -Namespace 'root\Microsoft\Windows\DeviceGuard'
    if ($null -eq $deviceGuard) {
        return 'Unavailable'
    }

    $services = @($deviceGuard.SecurityServicesRunning)
    if ($services.Count -eq 0) {
        return 'Not running'
    }

    return "Running services: $($services -join ', ')"
}

function Get-PendingRebootState {
    $servicingPaths = [ordered]@{
        'CBS RebootPending' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'CBS PackagesPending' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
        'Windows Update RebootRequired' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    }

    $servicingReasons = @(
        foreach ($entry in $servicingPaths.GetEnumerator()) {
            if (Test-Path -LiteralPath $entry.Value) { $entry.Key }
        }
    )
    $renameEntries = @(Get-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations')

    if ($servicingReasons.Count -gt 0) {
        return [pscustomobject]@{
            Classification = 'Servicing'
            Status = "Windows servicing reboot required: $($servicingReasons -join ', ')"
            Recommendation = 'Restart before controlled benchmarks or ranked play.'
            Evidence = "Classification=Servicing; Reasons=$($servicingReasons -join ', ')"
            RequiresReboot = $true
            Level = 'Warning'
        }
    }

    if ($renameEntries.Count -gt 0) {
        return [pscustomobject]@{
            Classification = 'Cleanup'
            Status = 'App or driver cleanup file is waiting for reboot. This is usually not a Windows servicing problem.'
            Recommendation = 'Reboot later if this persists, or after installing drivers/updates.'
            Evidence = "Classification=Cleanup; PendingFileRenameCount=$($renameEntries.Count); Entries=$($renameEntries -join ' | ')"
            RequiresReboot = $RequiresReboot
            Level = 'Info'
        }
    }

    return [pscustomobject]@{
        Classification = 'None'
        Status = 'No pending reboot markers detected'
        Recommendation = 'No action needed.'
        Evidence = 'Classification=None'
        RequiresReboot = $false
        Level = 'Info'
    }
}

function New-Check {
    param(
        [string]$Id,
        [string]$Name,
        [ValidateSet('Info', 'Warning', 'Critical')]
        [string]$Level,
        [string]$Status,
        [string]$Recommendation,
        [string]$Evidence,
        [bool]$RequiresReboot = $false
    )

    [pscustomobject]@{
        Id = $Id
        Name = $Name
        Level = $Level
        Status = $Status
        Recommendation = $Recommendation
        Evidence = $Evidence
        RollbackAvailable = 'Not required for read-only scan'
        RequiresReboot = $false
    }
}

$os = Get-FirstCimInstance -ClassName 'Win32_OperatingSystem'
$computer = Get-FirstCimInstance -ClassName 'Win32_ComputerSystem'
$cpu = Get-FirstCimInstance -ClassName 'Win32_Processor'
$gpus = Get-AllCimInstances -ClassName 'Win32_VideoController'
$nvidiaGpu = $gpus | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
$steamProcess = Get-Process -Name 'steam' -ErrorAction SilentlyContinue | Select-Object -First 1
$haloSteamProcess = Get-Process -Name 'HaloInfinite' -ErrorAction SilentlyContinue | Select-Object -First 1
$capFrameX = Get-Command 'CapFrameX.exe' -ErrorAction SilentlyContinue
$presentMon = Get-Command 'PresentMon.exe' -ErrorAction SilentlyContinue
$nvidiaSmi = Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue
$rtss = Get-Process -Name 'RTSS' -ErrorAction SilentlyContinue | Select-Object -First 1
$afterburner = Get-Process -Name 'MSIAfterburner' -ErrorAction SilentlyContinue | Select-Object -First 1

$hags = Get-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode'
$mpo = Get-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode'
$gameMode = Get-RegistryValue -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled'
$gameDvr = Get-RegistryValue -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled'
$secureBoot = Get-SecureBootState
$vbs = Get-VbsState
$pendingReboot = Get-PendingRebootState

$checks = New-Object System.Collections.Generic.List[object]

$windowsCaption = if ($null -ne $os) { "$($os.Caption) build $($os.BuildNumber)" } else { 'Unavailable' }
$windowsLevel = if ($null -ne $os -and [int]$os.BuildNumber -ge 22000) { 'Info' } else { 'Warning' }
$checks.Add((New-Check -Id 'windows-version' -Name 'Windows version' -Level $windowsLevel -Status $windowsCaption -Recommendation 'Use Windows 11 22H2 or newer for the intended GPTOPT baseline.' -Evidence $windowsCaption))

$gpuStatus = if ($null -ne $nvidiaGpu) { "$($nvidiaGpu.Name), driver $($nvidiaGpu.DriverVersion)" } elseif ($gpus.Count -gt 0) { ($gpus.Name -join '; ') } else { 'No GPU detected through WMI' }
$gpuLevel = if ($null -ne $nvidiaGpu) { 'Info' } else { 'Warning' }
$checks.Add((New-Check -Id 'gpu-vendor' -Name 'GPU vendor and driver' -Level $gpuLevel -Status $gpuStatus -Recommendation 'NVIDIA Profile Inspector presets only apply to NVIDIA GPUs; non-NVIDIA systems should stay in audit/report mode.' -Evidence $gpuStatus))

$checks.Add((New-Check -Id 'hags' -Name 'Hardware accelerated GPU scheduling' -Level 'Info' -Status "HwSchMode=$hags" -Recommendation 'Record HAGS state before benchmark comparisons; do not change it without a rollback snapshot.' -Evidence "HKLM GraphicsDrivers HwSchMode=$hags"))
$checks.Add((New-Check -Id 'mpo' -Name 'Multiplane overlay state' -Level 'Info' -Status "OverlayTestMode=$mpo" -Recommendation 'Record MPO state before display-latency comparisons; this scanner does not edit registry.' -Evidence "HKLM Dwm OverlayTestMode=$mpo"))
$checks.Add((New-Check -Id 'game-mode' -Name 'Game Mode' -Level 'Info' -Status "AutoGameModeEnabled=$gameMode" -Recommendation 'Record Game Mode before benchmark comparisons.' -Evidence "HKCU GameBar AutoGameModeEnabled=$gameMode"))
$checks.Add((New-Check -Id 'game-dvr' -Name 'Game DVR' -Level 'Info' -Status "GameDVR_Enabled=$gameDvr" -Recommendation 'Record capture settings before benchmark comparisons.' -Evidence "HKCU GameConfigStore GameDVR_Enabled=$gameDvr"))
$checks.Add((New-Check -Id 'secure-boot' -Name 'Secure Boot' -Level 'Info' -Status $secureBoot -Recommendation 'Secure Boot is reported for compatibility context only; GPTOPT does not change it.' -Evidence $secureBoot))
$checks.Add((New-Check -Id 'vbs' -Name 'Virtualization based security' -Level 'Info' -Status $vbs -Recommendation 'VBS is reported for context only; this foundation router does not disable security features.' -Evidence $vbs))

$checks.Add((New-Check -Id 'pending-reboot' -Name 'Pending reboot markers' -Level $pendingReboot.Level -Status $pendingReboot.Status -Recommendation $pendingReboot.Recommendation -Evidence $pendingReboot.Evidence -RequiresReboot $pendingReboot.RequiresReboot))

$toolEvidence = @(
    "CapFrameX=$([bool]$capFrameX)",
    "PresentMon=$([bool]$presentMon)",
    "RTSS=$([bool]$rtss)",
    "MSIAfterburner=$([bool]$afterburner)",
    "nvidia-smi=$([bool]$nvidiaSmi)"
) -join '; '
$checks.Add((New-Check -Id 'benchmark-tools' -Name 'Benchmark tooling' -Level 'Info' -Status $toolEvidence -Recommendation 'Install or start only the tools needed for the benchmark plan.' -Evidence $toolEvidence))

$haloEvidence = @(
    "SteamRunning=$([bool]$steamProcess)",
    "HaloInfiniteRunning=$([bool]$haloSteamProcess)",
    "HaloSettingsPath=$(Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings\SpecControlSettings.json')"
) -join '; '
$checks.Add((New-Check -Id 'halo-steam-focus' -Name 'Halo Steam focus' -Level 'Info' -Status $haloEvidence -Recommendation 'Halo checks stay focused on Steam/local Halo files. Xbox App repair is intentionally not part of the default flow.' -Evidence $haloEvidence))

$system = [pscustomobject]@{
    Computer = if ($null -ne $computer) { $computer.Model } else { 'Unavailable' }
    Cpu = if ($null -ne $cpu) { $cpu.Name } else { 'Unavailable' }
    Windows = $windowsCaption
    Gpus = @($gpus | Select-Object Name, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
}

$result = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Context = $Context
    Root = $Root
    System = $system
    Checks = @($checks.ToArray())
    SafetyNotes = @(
        'Read-only safety scan.',
        'No registry edits.',
        'No Halo settings edits.',
        'No reboot behavior.',
        'No Xbox App repair by default.'
    )
}

if ($AsObject) {
    return $result
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
    return
}

Write-Host ''
Write-Host "=== GPTOPT Safety Scan ($Context) ===" -ForegroundColor Cyan
Write-Host 'Read-only scan. No registry edits, Halo setting edits, Xbox App repair, process kills, or reboot behavior.'
Write-Host ''
$result.Checks | Select-Object Id, Level, Name, Status, Recommendation | Format-Table -Wrap -AutoSize
