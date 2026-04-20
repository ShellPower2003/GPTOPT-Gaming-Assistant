function Show-Menu {
    Clear-Host
    Write-Host '=== GPTOPT Utility ===' -ForegroundColor Cyan
    Write-Host '1. System audit'
    Write-Host '2. Gaming optimization checklist'
    Write-Host '3. Cleanup checklist'
    Write-Host '4. Benchmark checklist'
    Write-Host '5. Exit'
    return (Read-Host 'Enter your choice (1-5)')
}

function Show-SystemAudit {
    Write-Host "`n[System Audit]" -ForegroundColor Yellow
    Write-Host '- Check Windows version, GPU driver, power plan, startup load, HAGS/MPO status, and active overlays.'
    Write-Host '- Validate Defender exclusions only if intentionally used.'
    Write-Host '- Review Event Viewer for display, WHEA, and app crash errors.'
}

function Show-GamingOptimization {
    Write-Host "`n[Gaming Optimization Checklist]" -ForegroundColor Yellow
    Write-Host '- Start with in-game settings and frame cap strategy.'
    Write-Host '- Then validate NVIDIA / display settings.'
    Write-Host '- Only then consider Windows registry or service changes.'
    Write-Host '- Record before/after frametime data with CapFrameX or PresentMon.'
}

function Show-Cleanup {
    Write-Host "`n[Cleanup Checklist]" -ForegroundColor Yellow
    Write-Host '- Remove stale overlays, disabled startup junk, and known conflicting utilities.'
    Write-Host '- Re-check game cache, launcher integrity, and GPU shader rebuild conditions.'
    Write-Host '- Keep rollback notes before making persistent changes.'
}

function Show-BenchmarkChecklist {
    Write-Host "`n[Benchmark Checklist]" -ForegroundColor Yellow
    Write-Host '- Fix map / route / scenario before comparing runs.'
    Write-Host '- Keep resolution scale, cap method, and sync method constant.'
    Write-Host '- Compare average FPS, 1% lows, GPU utilization, and frametime spikes.'
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
