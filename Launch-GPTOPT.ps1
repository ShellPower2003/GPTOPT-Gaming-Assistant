$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Pause-Continue {
    Write-Host ''
    Read-Host 'Press Enter to continue'
}

function Show-Header($Title) {
    Clear-Host
    Write-Host ("=== {0} ===" -f $Title) -ForegroundColor Cyan
    Write-Host ''
}

function Show-TextFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "Missing file: $Path" -ForegroundColor Red
        return
    }

    Get-Content -Path $Path
}

function Get-RegValueOrDefault {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Default = 'Not set / default'
    )

    try {
        $item = Get-ItemProperty -Path $Path -ErrorAction Stop
        $value = $item.$Name
        if ($null -eq $value -or $value -eq '') { return $Default }
        return $value
    } catch {
        return $Default
    }
}

function Run-ReadOnlyAudit {
    Show-Header 'GPTOPT Read-Only Audit'

    try {
        $os = Get-ComputerInfo
        Write-Host ("OS: {0} {1} (Build {2})" -f $os.WindowsProductName, $os.WindowsVersion, $os.OsBuildNumber)
    } catch {
        Write-Host 'OS: Unable to read detailed OS information'
    }

    try {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name, DriverVersion
        if ($gpu) {
            Write-Host ("GPU: {0}" -f $gpu.Name)
            Write-Host ("GPU Driver: {0}" -f $gpu.DriverVersion)
        }
    } catch {
        Write-Host 'GPU: Unable to read GPU information'
    }

    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name
        if ($cpu) { Write-Host ("CPU: {0}" -f $cpu.Name) }
    } catch {
        Write-Host 'CPU: Unable to read CPU information'
    }

    try {
        $activePlan = (powercfg /getactivescheme) 2>$null
        if ($activePlan) { Write-Host ("Power Plan: {0}" -f ($activePlan -join ' ')) }
    } catch {
        Write-Host 'Power Plan: Unable to read active plan'
    }

    $hags = Get-RegValueOrDefault -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode'
    $mpo  = Get-RegValueOrDefault -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode'

    Write-Host ("HAGS registry value: {0}" -f $hags)
    Write-Host ("MPO registry value: {0}" -f $mpo)

    try {
        $startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction Stop | Measure-Object).Count
        Write-Host ("Startup entries: {0}" -f $startupCount)
    } catch {
        Write-Host 'Startup entries: Unable to count'
    }

    try {
        $interesting = @('RTSS','MSIAfterburner','CapFrameX','PresentMon','Steam','Discord','nvcontainer')
        $running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $interesting -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique
        if ($running) {
            Write-Host ("Known tooling processes: {0}" -f ($running -join ', '))
        } else {
            Write-Host 'Known tooling processes: none detected from quick list'
        }
    } catch {
        Write-Host 'Known tooling processes: Unable to check'
    }

    Write-Host ''
    Write-Host 'Available next steps from this launcher:' -ForegroundColor Yellow
    Write-Host '- benchmark analysis template'
    Write-Host '- NVIDIA profile strategy guide'
    Write-Host '- Windows graphics baseline guide'
    Write-Host '- preset checklist scripts'
    Write-Host '- registry bundle folder'
}

function Show-DocsMenu {
    do {
        Show-Header 'Docs'
        Write-Host '1. Benchmark analysis template'
        Write-Host '2. NVIDIA profile strategy'
        Write-Host '3. Windows graphics baseline'
        Write-Host '4. CapFrameX and PresentMon guide'
        Write-Host '5. Back'
        $choice = Read-Host 'Choose'

        switch ($choice) {
            '1' { Show-Header 'Benchmark Analysis Template'; Show-TextFile (Join-Path $RepoRoot 'docs/BENCHMARK_ANALYSIS_TEMPLATE.md'); Pause-Continue }
            '2' { Show-Header 'NVIDIA Profile Strategy'; Show-TextFile (Join-Path $RepoRoot 'docs/NVIDIA_PROFILE_STRATEGY.md'); Pause-Continue }
            '3' { Show-Header 'Windows Graphics Baseline'; Show-TextFile (Join-Path $RepoRoot 'docs/WINDOWS_GRAPHICS_BASELINE.md'); Pause-Continue }
            '4' { Show-Header 'CapFrameX / PresentMon Guide'; Show-TextFile (Join-Path $RepoRoot 'docs/CAPFRAMEX_PRESENTMON_GUIDE.md'); Pause-Continue }
        }
    } while ($choice -ne '5')
}

function Show-PresetsMenu {
    do {
        Show-Header 'Preset Checklist Scripts'
        Write-Host '1. Competitive latency baseline'
        Write-Host '2. Visual quality baseline'
        Write-Host '3. Back'
        $choice = Read-Host 'Choose'

        switch ($choice) {
            '1' { & (Join-Path $RepoRoot 'Profiles/Competitive-Latency-Baseline.ps1'); Pause-Continue }
            '2' { & (Join-Path $RepoRoot 'Profiles/Visual-Quality-Baseline.ps1'); Pause-Continue }
        }
    } while ($choice -ne '3')
}

function Show-RegistryMenu {
    Show-Header 'Registry Bundles'
    Write-Host 'Available files:' -ForegroundColor Yellow
    Get-ChildItem -Path (Join-Path $RepoRoot 'Registry') -File | Select-Object Name, FullName | Format-Table -AutoSize
    Write-Host ''
    Write-Host 'These are file-based templates. Review before importing.' -ForegroundColor Yellow
    Pause-Continue
}

function Open-RepoRoot {
    Start-Process explorer.exe $RepoRoot
}

function Show-MainMenu {
    do {
        Show-Header 'GPTOPT Launcher'
        Write-Host '1. Run read-only system audit'
        Write-Host '2. Open docs menu'
        Write-Host '3. Open preset checklist scripts'
        Write-Host '4. Show registry bundles'
        Write-Host '5. Open repo folder in Explorer'
        Write-Host '6. Exit'
        $choice = Read-Host 'Choose'

        switch ($choice) {
            '1' { Run-ReadOnlyAudit; Pause-Continue }
            '2' { Show-DocsMenu }
            '3' { Show-PresetsMenu }
            '4' { Show-RegistryMenu }
            '5' { Open-RepoRoot }
            '6' { Write-Host 'Exiting...' -ForegroundColor Green }
            default { if ($choice -ne '6') { Write-Host 'Invalid choice.' -ForegroundColor Red; Pause-Continue } }
        }
    } while ($choice -ne '6')
}

Show-MainMenu
