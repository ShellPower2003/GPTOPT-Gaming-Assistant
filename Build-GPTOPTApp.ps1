#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')]
    [string]$Configuration = 'Release',
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$Root = Split-Path -Parent $PSCommandPath
$Project = Join-Path $Root 'src\GPTOPT.App\GPTOPT.App.csproj'
$Output = Join-Path $Root 'dist\win-x64'

function Set-BuildProgress([int]$Percent,[string]$Status) {
    Write-Progress -Activity 'GPTOPT Native App Build' -Status "$Percent% - $Status" -PercentComplete $Percent
}

Set-BuildProgress 5 'Checking .NET SDK'
$dotnet = Get-Command dotnet.exe -ErrorAction Stop
$version = & $dotnet.Source --version
if ([version]($version.Split('-')[0]) -lt [version]'8.0.0') {
    throw ".NET SDK 8 or newer is required. Found $version"
}

Set-BuildProgress 20 'Restoring dependencies'
& $dotnet.Source restore $Project
if ($LASTEXITCODE -ne 0) { throw 'dotnet restore failed.' }

Set-BuildProgress 45 'Building native desktop application'
& $dotnet.Source build $Project -c $Configuration --no-restore
if ($LASTEXITCODE -ne 0) { throw 'dotnet build failed.' }

Set-BuildProgress 70 'Publishing self-contained Windows executable'
if (Test-Path $Output) { Remove-Item $Output -Recurse -Force }
& $dotnet.Source publish $Project -c $Configuration -r win-x64 --self-contained true -p:PublishSingleFile=true -o $Output
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

$Exe = Join-Path $Output 'GPTOPT.exe'
if (-not (Test-Path $Exe)) { throw "Published executable not found: $Exe" }

Set-BuildProgress 95 'Creating desktop shortcut'
try {
    $ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPTOPT Gaming Assistant.lnk'
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Exe
    $Shortcut.WorkingDirectory = $Output
    $Shortcut.Description = 'GPTOPT native PC gaming diagnostics and optimization application'
    $Shortcut.Save()
} catch {
    Write-Warning "Shortcut creation failed: $($_.Exception.Message)"
}

Set-BuildProgress 100 'Complete'
Write-Progress -Activity 'GPTOPT Native App Build' -Completed
Write-Host "GPTOPT native app ready: $Exe" -ForegroundColor Green
if ($Run) { Start-Process $Exe }
