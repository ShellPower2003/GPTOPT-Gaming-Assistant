function Show-Menu {
    Clear-Host
    Write-Host '=== GPTOPT Utility ===' -ForegroundColor Cyan
    Write-Host '1. Read-only system audit'
    Write-Host '2. Gaming optimization checklist'
    Write-Host '3. Cleanup checklist'
    Write-Host '4. Benchmark checklist'
    Write-Host '5. Exit'
    return (Read-Host 'Enter your choice (1-5)')
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

function Show-SystemAudit {
    Write-Host "`n=== READ-ONLY SYSTEM AUDIT ===" -ForegroundColor Yellow

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
        $interesting = @('RTSS','MSIAfterburner','CapFrameX','PresentMon','Steam','Discord','NVIDIA App','nvcontainer')
        $running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $interesting -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique
        if ($running) {
            Write-Host ("Known overlay / tooling processes: {0}" -f ($running -join ', '))
        } else {
            Write-Host 'Known overlay / tooling processes: none detected from quick list'
        }
    } catch {
        Write-Host 'Known overlay / tooling processes: Unable to check'
    }

    Write-Host "`nNext step: compare these values against your intended gaming baseline before changing anything." -ForegroundColor Cyan
}

function Show-GamingOptimization {
    Write-Host "`n=== GAMING OPTIMIZATION CHECKLIST ===" -ForegroundColor Yellow
    Write-Host '- Lock the test case first: same map, route, cap, sync mode, and resolution scale.'
    Write-Host '- Start with in-game settings and frame-cap behavior.'
    Write-Host '- Then validate NVIDIA / display settings.'
    Write-Host '- Only then consider Windows registry or service changes.'
    Write-Host '- Record before/after frametime data with CapFrameX or PresentMon.'
}

function Show-Cleanup {
    Write-Host "`n=== CLEANUP CHECKLIST ===" -ForegroundColor Yellow
    Write-Host '- Remove stale overlays, disabled startup junk, and conflicting utilities.'
    Write-Host '- Re-check launcher integrity, game files, and shader rebuild conditions.'
    Write-Host '- Keep rollback notes before making persistent changes.'
    Write-Host '- Reboot only when a driver-level or service-level change actually requires it.'
}

function Show-BenchmarkChecklist {
    Write-Host "`n=== BENCHMARK CHECKLIST ===" -ForegroundColor Yellow
    Write-Host '- Fix route, duration, map, and scenario before comparing runs.'
    Write-Host '- Keep resolution scale, cap method, sync method, and background load constant.'
    Write-Host '- Compare average FPS, 1% lows, GPU utilization, and frametime spikes.'
    Write-Host '- Do not compare runs with different hidden variables and call it a real conclusion.'
}

do {
    $choice = Show-Menu
    switch ($choice) {
        '1' { Show-SystemAudit }
        '2' { Show-GamingOptimization }
        '3' { Show-Cleanup }
        '4' { Show-BenchmarkChecklist }
        '5' { Write-Host 'Exiting...' -ForegroundColor Green }
        default { Write-Host 'Invalid choice. Try again.' -ForegroundColor Red }
    }

    if ($choice -ne '5') {
        Write-Host ''
        Read-Host 'Press Enter to continue'
    }
} while ($choice -ne '5')
