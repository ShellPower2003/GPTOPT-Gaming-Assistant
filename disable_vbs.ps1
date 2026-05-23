[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$Audit
)

$ErrorActionPreference = 'Stop'

$Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
$Name = 'EnableVirtualizationBasedSecurity'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw 'This script requires Administrator PowerShell.'
}

$current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

if ($Audit) {
    if ($null -eq $current) {
        Write-Host 'VBS registry value is not set.'
    } else {
        Write-Host "Current $Name value: $($current.$Name)"
    }

    return
}

if (-not $Force) {
    Write-Warning 'This changes a Windows security-related setting. Benchmark first and keep rollback notes.'
    $answer = Read-Host 'Type DISABLE to continue'

    if ($answer -ne 'DISABLE') {
        Write-Host 'Cancelled.'
        return
    }
}

if ($PSCmdlet.ShouldProcess($Path, "Set $Name to 0")) {
    New-Item -Path $Path -Force | Out-Null
    Set-ItemProperty -Path $Path -Name $Name -Value 0 -Type DWord
    Write-Host 'VBS registry setting changed. Restart Windows for the change to fully apply.' -ForegroundColor Yellow
}

