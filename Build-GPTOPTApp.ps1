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

Set-BuildProgress 5 'Checking .NET SDK and source files'
$dotnet = Get-Command dotnet.exe -ErrorAction Stop
$version = & $dotnet.Source --version
if ([version]($version.Split('-')[0]) -lt [version]'8.0.0') {
    throw ".NET SDK 8 or newer is required. Found $version"
}
if (-not (Test-Path $Project)) { throw "Project not found: $Project" }
if (-not (Test-Path $Xaml)) { throw "XAML not found: $Xaml" }

Set-BuildProgress 9 'Wiring current application workflows'
$xamlText = Get-Content -Raw -LiteralPath $Xaml
$oldButton = '<Button Grid.Column="1" Content="Run Session Check" Click="RunTargetedDiagnostics_Click" Style="{StaticResource PrimaryButton}" Padding="24,12"/>'
$newButton = '<Button Grid.Column="1" Content="Prepare for Halo" Click="PrepareForHalo_Click" Style="{StaticResource PrimaryButton}" Padding="24,12"/>'
if ($xamlText.Contains($oldButton)) { $xamlText = $xamlText.Replace($oldButton, $newButton) }
$xamlText = $xamlText.Replace('Click="OpenPresentMon_Click"','Click="OpenPresentMonRobust_Click"')
Set-Content -LiteralPath $Xaml -Value $xamlText -Encoding UTF8
if (-not $xamlText.Contains('Click="PrepareForHalo_Click"')) { throw 'Prepare for Halo button is missing from MainWindow.xaml.' }
if (-not $xamlText.Contains('Click="OpenPresentMonRobust_Click"')) { throw 'Robust PresentMon handler is not wired in MainWindow.xaml.' }

Set-BuildProgress 12 'Validating XAML'
try { [xml](Get-Content -Raw -LiteralPath $Xaml) | Out-Null }
catch { throw "MainWindow.xaml is invalid XML: $($_.Exception.Message)" }

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
    $Shortcut.Description = 'GPTOPT native PC gaming diagnostics and optimization application'
    $Shortcut.Save()
} catch {
    Write-Warning "Shortcut creation failed: $($_.Exception.Message)"
}

Set-BuildProgress 100 'Complete'
Write-Progress -Activity 'GPTOPT Native App Build' -Completed
Write-Host "GPTOPT native app ready: $Exe" -ForegroundColor Green
if ($Run) { Start-Process $Exe }
