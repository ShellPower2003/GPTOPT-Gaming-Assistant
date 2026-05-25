$ErrorActionPreference = 'Stop'

Write-Host "`n=== GPTOPT Bootstrap ===" -ForegroundColor Cyan
Write-Host "No reboot. Clones or updates the repo, then launches GPTOPT.`n" -ForegroundColor Green

$RepoUrl  = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant.git'
$ZipUrl   = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant/archive/refs/heads/main.zip'
$BaseDir  = Join-Path $env:USERPROFILE 'GPTOPT'
$RepoDir  = Join-Path $BaseDir 'GPTOPT-Gaming-Assistant'
$ZipPath  = Join-Path $BaseDir 'GPTOPT-main.zip'
$TempDir  = Join-Path $BaseDir 'zip_extract'

function Write-OK($m){ Write-Host "[OK]  $m" -ForegroundColor Green }
function Write-Step($m){ Write-Host "[DO]  $m" -ForegroundColor Yellow }
function Write-Bad($m){ Write-Host "[BAD] $m" -ForegroundColor Red }

New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

$git = Get-Command git.exe -ErrorAction SilentlyContinue

if($git){
    if(Test-Path (Join-Path $RepoDir '.git')){
        Write-Step "Updating existing repo: $RepoDir"
        Push-Location $RepoDir
        git pull --ff-only
        Pop-Location
        Write-OK "Repo updated"
    }
    elseif(Test-Path $RepoDir){
        Write-Step "Repo folder exists but is not a git clone. Keeping it and using ZIP fallback."
        $git = $null
    }
    else{
        Write-Step "Cloning repo to: $RepoDir"
        git clone $RepoUrl $RepoDir
        Write-OK "Repo cloned"
    }
}

if(-not $git){
    Write-Step "Git not available. Downloading ZIP fallback."
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    $Extracted = Join-Path $TempDir 'GPTOPT-Gaming-Assistant-main'
    if(Test-Path $RepoDir){
        $Backup = "$RepoDir.backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
        Write-Step "Backing up existing folder to: $Backup"
        Rename-Item $RepoDir $Backup
    }
    Move-Item $Extracted $RepoDir
    Write-OK "Repo downloaded by ZIP"
}

$Launcher = Join-Path $RepoDir 'Launch-GPTOPT.ps1'
if(!(Test-Path $Launcher)){
    Write-Bad "Launcher missing: $Launcher"
    exit 1
}

Write-Step "Launching GPTOPT menu"
Set-Location $RepoDir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Launcher
