[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Audit', 'ApplyEsports', 'Reset')]
    [string]$Mode = 'Audit',

    [string]$StatePath = "$PSScriptRoot\..\Registry\gptopt-service-state.json"
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step {
    param([string]$Message)
    Write-Host "[GPTOPT] $Message" -ForegroundColor Cyan
}

function Get-ServiceSnapshot {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

        if ($null -eq $svc) {
            [pscustomobject]@{
                Name      = $name
                Exists    = $false
                Status    = $null
                StartType = $null
            }
            continue
        }

        $wmi = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue

        [pscustomobject]@{
            Name      = $name
            Exists    = $true
            Status    = $svc.Status.ToString()
            StartType = $wmi.StartMode
        }
    }
}

function Save-ServiceSnapshot {
    param(
        [string[]]$Names,
        [string]$Path
    )

    $snapshot = Get-ServiceSnapshot -Names $Names
    $dir = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $snapshot | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Step "Saved service snapshot to $Path"
}

function Set-ServiceSafe {
    param(
        [string]$Name,

        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string]$StartupType,

        [ValidateSet('Start', 'Stop', 'None')]
        [string]$Action = 'None'
    )

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue

    if ($null -eq $svc) {
        Write-Warning "Service not found: $Name"
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set startup type to $StartupType")) {
        Set-Service -Name $Name -StartupType $StartupType
    }

    if ($Action -eq 'Stop' -and $svc.Status -ne 'Stopped') {
        if ($PSCmdlet.ShouldProcess($Name, 'Stop service')) {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
    }

    if ($Action -eq 'Start' -and $svc.Status -ne 'Running') {
        if ($PSCmdlet.ShouldProcess($Name, 'Start service')) {
            Start-Service -Name $Name -ErrorAction SilentlyContinue
        }
    }
}

function Restore-ServiceSnapshot {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No saved service snapshot found at $Path"
    }

    $snapshot = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json

    foreach ($item in $snapshot) {
        if (-not $item.Exists) {
            Write-Warning "Skipping missing service from snapshot: $($item.Name)"
            continue
        }

        $startupType = switch ($item.StartType) {
            'Auto' { 'Automatic' }
            'Manual' { 'Manual' }
            'Disabled' { 'Disabled' }
            default { 'Manual' }
        }

        $action = if ($item.Status -eq 'Running') { 'Start' } else { 'Stop' }

        Set-ServiceSafe -Name $item.Name -StartupType $startupType -Action $action
    }
}

$services = @('SysMain', 'DiagTrack')

switch ($Mode) {
    'Audit' {
        Write-Step 'Service state audit'
        Get-ServiceSnapshot -Names $services | Format-Table -AutoSize
    }

    'ApplyEsports' {
        if (-not (Test-IsAdmin)) {
            throw 'ApplyEsports requires Administrator PowerShell.'
        }

        Save-ServiceSnapshot -Names $services -Path $StatePath

        Write-Step 'Applying esports service profile'
        Set-ServiceSafe -Name 'SysMain' -StartupType Disabled -Action Stop
        Set-ServiceSafe -Name 'DiagTrack' -StartupType Disabled -Action Stop

        Write-Step 'Done. Reboot only if you are comparing a clean before/after benchmark.'
    }

    'Reset' {
        if (-not (Test-IsAdmin)) {
            throw 'Reset requires Administrator PowerShell.'
        }

        Write-Step 'Restoring previous service state'
        Restore-ServiceSnapshot -Path $StatePath
        Write-Step 'Reset complete.'
    }
}
