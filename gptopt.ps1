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
foreach ($p in @($Scripts,$Reports,$Backups,$Logs)) { Ensure-Directory $p }

$GuiCandidates = @(
    (Join-Path $Scripts 'Invoke-GPTOPTControlCenter.ps1'),
    (Join-Path $Scripts 'Invoke-GPTOPTAppGUI.ps1'),
    (Join-Path $Root 'Launch-GPTOPT.ps1'),
    (Join-Path $Root 'Run-GPTOPT.ps1')
)

$Entry = $GuiCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (!$Entry) {
    Say 'No GUI entry found. Creating minimal local launcher.' 'Yellow'
    $Entry = Join-Path $Root 'Run-GPTOPT.ps1'
    @'
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("GPTOPT repo installed, but no GUI entry file was found. Add Scripts\Invoke-GPTOPTControlCenter.ps1 as the main app entry.", "GPTOPT") | Out-Null
'@ | Set-Content -Path $Entry -Encoding UTF8
}

$Run = Join-Path $Root 'Run-GPTOPT.ps1'
@"
`$ErrorActionPreference = 'Stop'
`$Root = Split-Path -Parent `$PSCommandPath
`$Candidates = @(
    (Join-Path `$Root 'Scripts\Invoke-GPTOPTControlCenter.ps1'),
    (Join-Path `$Root 'Scripts\Invoke-GPTOPTAppGUI.ps1'),
    (Join-Path `$Root 'Launch-GPTOPT.ps1')
)
`$Entry = `$Candidates | Where-Object { Test-Path -LiteralPath `$_ } | Select-Object -First 1
if (!`$Entry) { throw 'No GPTOPT GUI entry file found.' }
& `$Entry
"@ | Set-Content -Path $Run -Encoding UTF8

$Cmd = Join-Path $Root 'GPTOPT_LAUNCHER.cmd'
@"
@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1"
"@ | Set-Content -Path $Cmd -Encoding ASCII

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
Say "Launching: $Run" 'Green'
Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Run`""
