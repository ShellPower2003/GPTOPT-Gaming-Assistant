[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')]
    [string]$Configuration = 'Release',
    [switch]$Run
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) {
        $forward = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Configuration',$Configuration)
        if ($Run) { $forward += '-Run' }
        & $pwsh.Source @forward
        exit $LASTEXITCODE
    }
    throw 'PowerShell 7 is required and pwsh.exe was not found.'
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$Root = Split-Path -Parent $PSCommandPath
$Project = Join-Path $Root 'src\GPTOPT.App\GPTOPT.App.csproj'
$Xaml = Join-Path $Root 'src\GPTOPT.App\MainWindow.xaml'
$Output = Join-Path $Root 'dist\win-x64'

function Set-BuildProgress([int]$Percent,[string]$Status) {
    Write-Progress -Activity 'GPTOPT Native App Build' -Status "$Percent% - $Status" -PercentComplete $Percent
}

Set-BuildProgress 5 'Checking SDK and source files'
$dotnet = Get-Command dotnet.exe -ErrorAction Stop
$version = & $dotnet.Source --version
if ([version]($version.Split('-')[0]) -lt [version]'8.0.0') {
    throw ".NET SDK 8 or newer is required. Found $version"
}
if (-not (Test-Path $Project)) { throw "Project not found: $Project" }
if (-not (Test-Path $Xaml)) { throw "XAML not found: $Xaml" }

Set-BuildProgress 10 'Validating product workflow wiring'
$xamlText = Get-Content -Raw -LiteralPath $Xaml
$requiredHandlers = @(
    'Click="PrepareForHalo_Click"',
    'Click="OpenPresentMonRobust_Click"',
    'Content="View What Needs Attention"'
)
foreach ($required in $requiredHandlers) {
    if (-not $xamlText.Contains($required)) { throw "Required UI wiring is missing: $required" }
}

Set-BuildProgress 14 'Validating XAML'
try { [xml]$xamlText | Out-Null }
catch { throw "MainWindow.xaml is invalid XML: $($_.Exception.Message)" }

Set-BuildProgress 22 'Restoring dependencies'
& $dotnet.Source restore $Project
if ($LASTEXITCODE -ne 0) { throw 'dotnet restore failed.' }

Set-BuildProgress 46 'Building native desktop application'
& $dotnet.Source build $Project -c $Configuration --no-restore
if ($LASTEXITCODE -ne 0) { throw 'dotnet build failed.' }

Set-BuildProgress 72 'Publishing self-contained Windows executable'
if (Test-Path $Output) { Remove-Item $Output -Recurse -Force }
& $dotnet.Source publish $Project -c $Configuration -r win-x64 --self-contained true -p:PublishSingleFile=true -o $Output
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

$Exe = Join-Path $Output 'GPTOPT.exe'
$Backend = Join-Path $Output 'Scripts\Invoke-GPTOPTAudit.ps1'
if (-not (Test-Path $Exe)) { throw "Published executable not found: $Exe" }
if (-not (Test-Path $Backend)) { throw "Packaged audit backend not found: $Backend" }

Set-BuildProgress 88 'Running package smoke checks'
$info = Get-Item $Exe
if ($info.Length -lt 1MB) { throw "Published executable is unexpectedly small: $($info.Length) bytes" }

Set-BuildProgress 95 'Creating desktop shortcut'
try {
    $ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPTOPT Gaming Assistant.lnk'
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Exe
    $Shortcut.WorkingDirectory = $Output
    $Shortcut.Description = 'GPTOPT Halo performance readiness, diagnostics, and measurement assistant'
    $Shortcut.Save()
} catch {
    Write-Warning "Shortcut creation failed: $($_.Exception.Message)"
}

Set-BuildProgress 100 'Complete'
Write-Progress -Activity 'GPTOPT Native App Build' -Completed
Write-Host "GPTOPT native app ready: $Exe" -ForegroundColor Green
if ($Run) { Start-Process $Exe }
