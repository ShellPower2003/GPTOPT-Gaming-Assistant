param(
    [ValidateSet('guided', 'gui', 'advanced', 'test', 'control', 'safety', 'recommend', 'queue', 'backupPlan', 'report')]
    [string]$Mode = 'guided',

    [ValidateSet('NormalGaming', 'BenchmarkCapture', 'HaloTroubleshooting', 'FullOptimizationPreview')]
    [string]$Context = 'NormalGaming'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsRoot = Join-Path $Root 'Scripts'
$ReportsRoot = Join-Path $Root 'Reports'
$HaloSightRoot = Join-Path $Root 'HaloSight'
$HaloSightGui = Join-Path $HaloSightRoot 'scripts\HaloSightGUI.ps1'
$SmokeTest = Join-Path $HaloSightRoot 'tests\smoke_test.ps1'
$GuidedGui = Join-Path $ScriptsRoot 'Invoke-GPTOPTGuidedControlCenter.ps1'
$AdvancedGui = Join-Path $ScriptsRoot 'Invoke-GPTOPTControlCenter.ps1'
$AppGui = Join-Path $ScriptsRoot 'Invoke-GPTOPTAppGUI.ps1'
$SafetyScanner = Join-Path $ScriptsRoot 'Test-GPTOPTSafety.ps1'

function Write-GPTOPTHeader {
    param([string]$Title)

    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Invoke-GPTOPTScript {
    param(
        [string]$Path,
        [string[]]$Arguments = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required script not found: $Path"
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    exit $LASTEXITCODE
}

function Get-GPTOPTSafetyScan {
    if (-not (Test-Path -LiteralPath $SafetyScanner)) {
        throw "Safety scanner not found: $SafetyScanner"
    }

    & $SafetyScanner -Context $Context -AsObject
}

function New-GPTOPTPreviewQueue {
    param([string]$QueueContext)

    $allItems = @(
        [pscustomobject]@{
            Id = 'audit-system-state'
            Context = 'NormalGaming'
            Action = 'Read Windows, GPU, display, Game Mode, HAGS, MPO, VBS, Secure Boot, and pending reboot state.'
            Risk = 'Low'
            RollbackAvailable = 'Not required'
            RequiresAdmin = $false
            RequiresReboot = $false
            Status = 'PreviewOnly'
        },
        [pscustomobject]@{
            Id = 'review-steam-halo'
            Context = 'HaloTroubleshooting'
            Action = 'Inspect Steam-focused Halo process, install path, and HaloSight report readiness.'
            Risk = 'Low'
            RollbackAvailable = 'Not required'
            RequiresAdmin = $false
            RequiresReboot = $false
            Status = 'PreviewOnly'
        },
        [pscustomobject]@{
            Id = 'benchmark-capture-readiness'
            Context = 'BenchmarkCapture'
            Action = 'Check for CapFrameX, PresentMon, RTSS, MSI Afterburner, NVIDIA SMI, and active capture sessions.'
            Risk = 'Low'
            RollbackAvailable = 'Not required'
            RequiresAdmin = $false
            RequiresReboot = $false
            Status = 'PreviewOnly'
        },
        [pscustomobject]@{
            Id = 'preview-service-profile'
            Context = 'FullOptimizationPreview'
            Action = 'Describe SysMain and DiagTrack service profile changes without applying them.'
            Risk = 'Medium'
            RollbackAvailable = 'Yes, service snapshot required before apply in a future PR'
            RequiresAdmin = $true
            RequiresReboot = $false
            Status = 'BlockedUntilApplyFeature'
        },
        [pscustomobject]@{
            Id = 'preview-registry-profile'
            Context = 'FullOptimizationPreview'
            Action = 'Describe GameDVR, Game Mode, HAGS, and MPO registry profile changes without editing registry.'
            Risk = 'Medium'
            RollbackAvailable = 'Yes, registry export required before apply in a future PR'
            RequiresAdmin = $true
            RequiresReboot = $false
            Status = 'BlockedUntilApplyFeature'
        },
        [pscustomobject]@{
            Id = 'preview-halo-config-baseline'
            Context = 'FullOptimizationPreview'
            Action = 'Describe Halo settings baseline only. No Halo config files are edited.'
            Risk = 'Medium'
            RollbackAvailable = 'Yes, Halo settings backup required before apply in a future PR'
            RequiresAdmin = $false
            RequiresReboot = $false
            Status = 'BlockedUntilApplyFeature'
        }
    )

    if ($QueueContext -eq 'FullOptimizationPreview') {
        return $allItems
    }

    $allItems | Where-Object { $_.Context -in @('NormalGaming', $QueueContext) }
}

function Show-GPTOPTQueue {
    param([string]$QueueContext)

    Write-GPTOPTHeader "GPTOPT Preview Queue ($QueueContext)"
    Write-Host 'Preview-first queue only. Nothing is applied, no registry keys are edited, Halo settings are not changed, and no reboot is triggered.'
    New-GPTOPTPreviewQueue -QueueContext $QueueContext |
        Format-Table Id, Context, Risk, RequiresAdmin, RequiresReboot, Status -AutoSize
}

function Show-GPTOPTBackupPlan {
    param([string]$PlanContext)

    Write-GPTOPTHeader "GPTOPT Rollback Snapshot Plan ($PlanContext)"
    Write-Host 'This is a plan only. Snapshot creation is intentionally not implemented in this foundation PR.'
    @(
        [pscustomobject]@{
        Step = 'System restore point'
        Purpose = 'Rollback high-impact Windows changes in a future apply workflow'
        Status = 'Planned'
        },
        [pscustomobject]@{
            Step = 'Registry export'
            Purpose = 'Capture exact keys before future registry tuning'
            Status = 'Planned'
        },
        [pscustomobject]@{
            Step = 'GPTOPT settings backup'
            Purpose = 'Preserve app configuration before future apply workflows'
            Status = 'Planned'
        },
        [pscustomobject]@{
            Step = 'Halo settings backup'
            Purpose = 'Preserve Steam Halo settings before any future Halo-focused apply workflow'
            Status = 'Planned'
        }
    ) | Format-Table -AutoSize
}

function Show-GPTOPTRecommendations {
    param([string]$RecommendationContext)

    $scan = Get-GPTOPTSafetyScan
    $warnings = @($scan.Checks | Where-Object { $_.Level -in @('Warning', 'Critical') })

    Write-GPTOPTHeader "GPTOPT Recommendations ($RecommendationContext)"
    Write-Host 'Read-only recommendations. Use these to decide what to benchmark or inspect next.'

    if ($warnings.Count -eq 0) {
        Write-Host 'No warning-level safety findings were detected.'
    } else {
        $warnings | Select-Object Id, Level, Name, Status, Recommendation | Format-Table -Wrap -AutoSize
    }

    Write-Host ''
    Write-Host 'Preview queue:'
    New-GPTOPTPreviewQueue -QueueContext $RecommendationContext |
        Select-Object Id, Risk, RollbackAvailable, RequiresReboot, Status |
        Format-Table -Wrap -AutoSize
}

function New-GPTOPTReport {
    param([string]$ReportContext)

    New-Item -ItemType Directory -Force -Path $ReportsRoot | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $markdownPath = Join-Path $ReportsRoot "GPTOPT-Report_$stamp.md"
    $jsonPath = Join-Path $ReportsRoot "GPTOPT-Report_$stamp.json"
    $scan = Get-GPTOPTSafetyScan
    $queue = @(New-GPTOPTPreviewQueue -QueueContext $ReportContext)
    $files = Get-ChildItem -LiteralPath $Root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\Reports\*" } |
        Select-Object -First 120 FullName, Length, LastWriteTime

    $report = [pscustomobject]@{
        GeneratedAt = (Get-Date).ToString('o')
        Context = $ReportContext
        Root = $Root
        Safety = $scan
        PreviewQueue = $queue
        EvidenceFiles = $files
        SafetyNotes = @(
            'Report generation is read-only except for writing this report under the repo Reports folder.',
            'No registry keys are edited.',
            'No Halo settings are edited.',
            'No reboot, shutdown, logoff, or process-kill behavior is triggered.',
            'Halo troubleshooting remains Steam-focused by default.'
        )
    }

    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $lines = @()
    $lines += '# GPTOPT Diagnostic Report'
    $lines += ''
    $lines += "- Generated: $($report.GeneratedAt)"
    $lines += "- Context: $ReportContext"
    $lines += "- Root: $Root"
    $lines += ''
    $lines += '## Safety Notes'
    foreach ($note in $report.SafetyNotes) {
        $lines += "- $note"
    }
    $lines += ''
    $lines += '## Safety Scan'
    foreach ($check in $scan.Checks) {
        $lines += "- [$($check.Level)] $($check.Name): $($check.Status) - $($check.Recommendation)"
    }
    $lines += ''
    $lines += '## Preview Queue'
    foreach ($item in $queue) {
        $lines += "- $($item.Id): $($item.Action) Risk=$($item.Risk); Rollback=$($item.RollbackAvailable); Reboot=$($item.RequiresReboot); Status=$($item.Status)"
    }
    $lines += ''
    $lines += '## Evidence Files'
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\')
        $lines += "- $relative ($($file.Length) bytes)"
    }

    $lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

    [pscustomobject]@{
        Markdown = $markdownPath
        Json = $jsonPath
    }
}

function Show-GPTOPTControl {
    Write-GPTOPTHeader 'GPTOPT App Router'
    Write-Host 'Central read-only router. Apply, rollback, registry editing, Halo config editing, and reboot behavior are not exposed here.'
    Write-Host ''
    Write-Host 'Available modes:'
    @(
        [pscustomobject]@{ Mode = 'guided'; Description = 'Launch Guided Control Center first' },
        [pscustomobject]@{ Mode = 'gui'; Description = 'Launch legacy HaloSight capture GUI' },
        [pscustomobject]@{ Mode = 'advanced'; Description = 'Launch Advanced Control Center' },
        [pscustomobject]@{ Mode = 'safety'; Description = 'Run compatibility and safety scan' },
        [pscustomobject]@{ Mode = 'recommend'; Description = 'Show context-aware recommendations' },
        [pscustomobject]@{ Mode = 'queue'; Description = 'Show preview-only action queue' },
        [pscustomobject]@{ Mode = 'backupPlan'; Description = 'Show rollback snapshot plan' },
        [pscustomobject]@{ Mode = 'report'; Description = 'Generate Markdown and JSON diagnostic report' },
        [pscustomobject]@{ Mode = 'test'; Description = 'Run HaloSight smoke test' }
    ) | Format-Table -AutoSize
}

switch ($Mode) {
    'guided' {
        if (Test-Path -LiteralPath $GuidedGui) {
            Invoke-GPTOPTScript -Path $GuidedGui
        }

        if (Test-Path -LiteralPath $AdvancedGui) {
            Invoke-GPTOPTScript -Path $AdvancedGui
        }

        Invoke-GPTOPTScript -Path $AppGui
    }
    'gui' {
        Invoke-GPTOPTScript -Path $HaloSightGui
    }
    'advanced' {
        if (Test-Path -LiteralPath $AdvancedGui) {
            Invoke-GPTOPTScript -Path $AdvancedGui
        }

        if (Test-Path -LiteralPath $AppGui) {
            Invoke-GPTOPTScript -Path $AppGui
        }

        Invoke-GPTOPTScript -Path $HaloSightGui
    }
    'test' {
        Invoke-GPTOPTScript -Path $SmokeTest
    }
    'control' {
        Show-GPTOPTControl
    }
    'safety' {
        Invoke-GPTOPTScript -Path $SafetyScanner -Arguments @('-Context', $Context)
    }
    'recommend' {
        Show-GPTOPTRecommendations -RecommendationContext $Context
    }
    'queue' {
        Show-GPTOPTQueue -QueueContext $Context
    }
    'backupPlan' {
        Show-GPTOPTBackupPlan -PlanContext $Context
    }
    'report' {
        $paths = New-GPTOPTReport -ReportContext $Context
        Write-GPTOPTHeader 'GPTOPT Report Generated'
        $paths | Format-List
    }
}
