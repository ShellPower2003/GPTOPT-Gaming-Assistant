<#
.SYNOPSIS
    Validates the GPTOPT repository without changing the local machine.

.DESCRIPTION
    Read-only repo health check for CI and local development. It validates PowerShell syntax,
    PowerShell data files, JSON syntax, expected repo paths, and common risky automation patterns.

    This script intentionally does not edit registry keys, services, drivers, power plans, NVIDIA profiles,
    controller settings, game configuration, or user files.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\Scripts\Test-GPTOPTRepoHealth.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Failures = 0
$script:Warnings = 0

function Write-GPTOPTResult {
    param(
        [ValidateSet('PASS', 'WARN', 'FAIL', 'ACTION')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    switch ($Level) {
        'PASS' {
            Write-Host "PASS: $Message"
        }
        'WARN' {
            $script:Warnings++
            Write-Warning "WARN: $Message"
        }
        'FAIL' {
            $script:Failures++
            Write-Error "FAIL: $Message" -ErrorAction Continue
        }
        'ACTION' {
            Write-Host "ACTION: $Message"
        }
    }
}

function Get-RepoFile {
    param(
        [Parameter(Mandatory)]
        [string[]]$Include
    )

    Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Include $Include |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            $_.FullName -notmatch '[\\/]node_modules[\\/]' -and
            $_.FullName -notmatch '[\\/]bin[\\/]' -and
            $_.FullName -notmatch '[\\/]obj[\\/]'
        }
}

function Test-ExpectedPath {
    param(
        [Parameter(Mandatory)]
        [string[]]$RelativePath
    )

    foreach ($path in $RelativePath) {
        $fullPath = Join-Path $RepoRoot $path
        if (Test-Path -LiteralPath $fullPath) {
            Write-GPTOPTResult -Level PASS -Message "Expected path present: $path"
        }
        else {
            Write-GPTOPTResult -Level WARN -Message "Expected path missing: $path"
        }
    }
}

function Test-PowerShellSyntax {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$File
    )

    foreach ($item in $File) {
        try {
            $tokens = $null
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $item.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )

            if ($parseErrors.Count -gt 0) {
                foreach ($parseError in $parseErrors) {
                    Write-GPTOPTResult -Level FAIL -Message "$($item.FullName): $($parseError.Message)"
                }
            }
            else {
                Write-GPTOPTResult -Level PASS -Message "PowerShell syntax OK: $($item.FullName)"
            }
        }
        catch {
            Write-GPTOPTResult -Level FAIL -Message "Could not parse $($item.FullName): $($_.Exception.Message)"
        }
    }
}

function Test-PowerShellDataFile {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$File
    )

    foreach ($item in $File) {
        try {
            $null = Import-PowerShellDataFile -LiteralPath $item.FullName
            Write-GPTOPTResult -Level PASS -Message "PowerShell data file OK: $($item.FullName)"
        }
        catch {
            Write-GPTOPTResult -Level FAIL -Message "Invalid PowerShell data file $($item.FullName): $($_.Exception.Message)"
        }
    }
}

function Test-JsonSyntax {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$File
    )

    foreach ($item in $File) {
        try {
            $null = Get-Content -Raw -LiteralPath $item.FullName | ConvertFrom-Json
            Write-GPTOPTResult -Level PASS -Message "JSON syntax OK: $($item.FullName)"
        }
        catch {
            Write-GPTOPTResult -Level FAIL -Message "Invalid JSON in $($item.FullName): $($_.Exception.Message)"
        }
    }
}

function Test-UnsafePattern {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$File
    )

    $patterns = @(
        @{
            Name  = 'Automatic reboot or shutdown'
            Regex = '(?i)\b(Restart-Computer|Stop-Computer|shutdown\.exe|shutdown\s+/r|shutdown\s+/s)\b'
        },
        @{
            Name  = 'Force service/process termination'
            Regex = '(?i)\b(Stop-Service|Stop-Process)\b.*\s-Force\b'
        },
        @{
            Name  = 'Execution policy machine-wide change'
            Regex = '(?i)\bSet-ExecutionPolicy\b.*\s-Scope\s+(LocalMachine|MachinePolicy|UserPolicy)\b'
        },
        @{
            Name  = 'Unprompted destructive remove'
            Regex = '(?i)\bRemove-Item\b.*\s-Recurse\b.*\s-Force\b'
        },
        @{
            Name  = 'Defender/security disabling'
            Regex = '(?i)\b(Set-MpPreference)\b.*\s-Disable'
        },
        @{
            Name  = 'Firewall profile disabling'
            Regex = '(?i)\bSet-NetFirewallProfile\b.*\s-Enabled\s+\$?false\b'
        }
    )

    foreach ($item in $File) {
        $content = Get-Content -Raw -LiteralPath $item.FullName

        foreach ($pattern in $patterns) {
            if ($content -match $pattern.Regex) {
                Write-GPTOPTResult -Level WARN -Message "$($pattern.Name) pattern found in $($item.FullName). Review for backup, -WhatIf support, and undo guidance."
            }
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $RepoRoot)) {
        throw "RepoRoot not found: $RepoRoot"
    }

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    Write-GPTOPTResult -Level ACTION -Message "Repo root: $RepoRoot"

    Test-ExpectedPath -RelativePath @(
        'README.md',
        'PSScriptAnalyzerSettings.psd1',
        '.github/workflows/gptopt-ci.yml',
        'Scripts'
    )

    $powerShellFiles = @(Get-RepoFile -Include @('*.ps1', '*.psm1', '*.psd1'))
    $psDataFiles = @($powerShellFiles | Where-Object { $_.Extension -ieq '.psd1' })
    $jsonFiles = @(Get-RepoFile -Include @('*.json'))

    if ($powerShellFiles.Count -eq 0) {
        Write-GPTOPTResult -Level WARN -Message 'No PowerShell files found.'
    }
    else {
        Test-PowerShellSyntax -File $powerShellFiles
        Test-UnsafePattern -File $powerShellFiles
    }

    if ($psDataFiles.Count -gt 0) {
        Test-PowerShellDataFile -File $psDataFiles
    }

    if ($jsonFiles.Count -gt 0) {
        Test-JsonSyntax -File $jsonFiles
    }
    else {
        Write-GPTOPTResult -Level PASS -Message 'No JSON files found.'
    }

    Write-GPTOPTResult -Level ACTION -Message "Warnings: $script:Warnings"
    Write-GPTOPTResult -Level ACTION -Message "Failures: $script:Failures"

    if ($script:Failures -gt 0) {
        exit 1
    }

    exit 0
}
catch {
    Write-GPTOPTResult -Level FAIL -Message $_.Exception.Message
    exit 1
}
