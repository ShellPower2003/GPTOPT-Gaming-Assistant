# GPTOPT one-line bootstrap launcher
# Usage:
#   irm https://raw.githubusercontent.com/ShellPower2003/GPTOPT-Gaming-Assistant/main/gptopt.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant.git'
$ZipUrl  = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant/archive/refs/heads/main.zip'
$BaseDir = Join-Path $env:USERPROFILE 'Documents\GitHub'
$Root    = Join-Path $BaseDir 'GPTOPT-Gaming-Assistant'

function Say {
    param([string]$Message,[string]$Color='Cyan')
    Write-Host "[GPTOPT] $Message" -ForegroundColor $Color
}

function Ensure-Directory {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Say 'Starting GPTOPT bootstrap...'
Ensure-Directory $BaseDir

$git = Get-Command git.exe -ErrorAction SilentlyContinue

if ($git) {
    if (Test-Path -LiteralPath (Join-Path $Root '.git')) {
        Say "Updating existing repo: $Root"
        Push-Location $Root
        try {
            git pull --ff-only
        } finally {
            Pop-Location
        }
    } elseif (Test-Path -LiteralPath $Root) {
        Say "Existing folder found without .git: $Root" 'Yellow'
        Say 'Leaving local folder untouched and using it as-is.' 'Yellow'
    } else {
        Say "Cloning repo to: $Root"
        git clone $RepoUrl $Root
    }
} else {
    if (!(Test-Path -LiteralPath $Root)) {
        Say 'Git not found. Downloading repo zip fallback...' 'Yellow'
        $TempZip = Join-Path $env:TEMP 'gptopt-main.zip'
        $TempDir = Join-Path $env:TEMP ('gptopt-main-' + [guid]::NewGuid().ToString('N'))
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
        Expand-Archive -Path $TempZip -DestinationPath $TempDir -Force
        $Extracted = Get-ChildItem $TempDir -Directory | Select-Object -First 1
        Move-Item -Path $Extracted.FullName -Destination $Root -Force
    } else {
        Say "Using existing repo folder: $Root" 'Yellow'
    }
}

$Scripts = Join-Path $Root 'Scripts'
$Reports = Join-Path $Root 'Reports'
$Backups = Join-Path $Root 'Backups'
$Logs    = Join-Path $Root 'Logs'
$Knowledge = Join-Path $Root 'Knowledge'
foreach ($p in @($Scripts,$Reports,$Backups,$Logs,$Knowledge)) { Ensure-Directory $p }

$GuidedEntry   = Join-Path $Scripts 'Invoke-GPTOPTGuidedControlCenter.ps1'
$AdvancedEntry = Join-Path $Scripts 'Invoke-GPTOPTControlCenter.ps1'
$LegacyEntry   = Join-Path $Scripts 'Invoke-GPTOPTAppGUI.ps1'
$LaunchEntry   = Join-Path $Root 'Launch-GPTOPT.ps1'
$Run           = Join-Path $Root 'Run-GPTOPT.ps1'

if (!(Test-Path -LiteralPath $Run)) {
    $Entry = @($GuidedEntry, $AdvancedEntry, $LegacyEntry, $LaunchEntry) |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if (!$Entry) {
        throw 'GPTOPT installed, but no launcher entry file was found.'
    }

    $FallbackRun = Join-Path $Root 'GPTOPT-LaunchFallback.ps1'
    @('$ErrorActionPreference = ''Stop''', "& '$Entry'") |
        Set-Content -LiteralPath $FallbackRun -Encoding UTF8
    $Run = $FallbackRun
    Say "Tracked router missing; created fallback launcher: $FallbackRun" 'Yellow'
}

$Cmd = Join-Path $Root 'GPTOPT_LAUNCHER.cmd'
if (!(Test-Path -LiteralPath $Cmd)) {
    @"
@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1"
"@ | Set-Content -LiteralPath $Cmd -Encoding ASCII
}

try {
    $ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPTOPT Control Center.lnk'
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = 'powershell.exe'
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Run`""
    $Shortcut.WorkingDirectory = $Root
    $Shortcut.Description = 'GPTOPT Control Center'
    $Shortcut.Save()
    Say "Desktop shortcut ready: $ShortcutPath" 'Green'
} catch {
    Say "Desktop shortcut skipped: $($_.Exception.Message)" 'Yellow'
}

Say "Repo ready: $Root" 'Green'
Say "Preferred entry: Guided Control Center, then Advanced fallback" 'Green'
Say "Launching: $Run" 'Green'
Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Run`""