$ErrorActionPreference = 'Stop'

Write-Host "`n=== GPTOPT Bootstrap ===" -ForegroundColor Cyan
Write-Host "No reboot. Clones or updates the repo, then launches GPTOPT.`n" -ForegroundColor Green

$RepoUrl  = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant.git'
$ZipUrl   = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant/archive/refs/heads/main.zip'
$BaseDir  = Join-Path $env:USERPROFILE 'GPTOPT'
$RepoDir  = Join-Path $BaseDir 'GPTOPT-Gaming-Assistant'
$ZipPath  = Join-Path $BaseDir 'GPTOPT-main.zip'
$TempDir  = Join-Path $BaseDir 'zip_extract'

function OK($m){ Write-Host "[OK]  $m" -ForegroundColor Green }
function DO($m){ Write-Host "[DO]  $m" -ForegroundColor Yellow }
function BAD($m){ Write-Host "[BAD] $m" -ForegroundColor Red }

New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

$git = Get-Command git.exe -ErrorAction SilentlyContinue

if($git){
    if(Test-Path (Join-Path $RepoDir '.git')){
        DO "Updating existing repo: $RepoDir"
        Push-Location $RepoDir
        git pull --ff-only
        Pop-Location
        OK "Repo updated"
    }
    elseif(Test-Path $RepoDir){
        DO "Repo folder exists but is not a git clone. Keeping it and using ZIP fallback."
        $git = $null
    }
    else{
        DO "Cloning repo to: $RepoDir"
        git clone $RepoUrl $RepoDir
        OK "Repo cloned"
    }
}

if(-not $git){
    DO "Git not available. Downloading ZIP fallback."
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    $Extracted = Join-Path $TempDir 'GPTOPT-Gaming-Assistant-main'
    if(Test-Path $RepoDir){
        $Backup = "$RepoDir.backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
        DO "Backing up existing folder to: $Backup"
        Rename-Item $RepoDir $Backup
    }
    Move-Item $Extracted $RepoDir
    OK "Repo downloaded by ZIP"
}

$Launcher = Join-Path $RepoDir 'Launch-GPTOPT.ps1'
if(!(Test-Path $Launcher)){
    BAD "Launcher missing: $Launcher"
    exit 1
}

DO "Launching GPTOPT menu"
Set-Location $RepoDir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Launcher
