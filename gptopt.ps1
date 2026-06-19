# GPTOPT one-line bootstrap launcher
# Usage:
#   irm https://raw.githubusercontent.com/ShellPower2003/GPTOPT-Gaming-Assistant/main/gptopt.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant.git'
$DefaultRoot = Join-Path $env:USERPROFILE 'Documents\GitHub'
$InstallRoot = Join-Path $DefaultRoot 'GPTOPT-Gaming-Assistant'

function Write-GPTOPT {
    param([string]$Message,[string]$Color = 'Cyan')
    Write-Host "[GPTOPT] $Message"