[CmdletBinding()]
param(
    [ValidateSet('gui','legacy','test','rebuild')]
    [string]$Mode = 'gui'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$Root = Split-Path -Parent $PSCommandPath

function Show-Step([int]$Percent, [string]$Status) {
    Write-Progress -Activity 'Starting GPTOPT' -Status "$Percent% - $Status" -PercentComplete $Percent
}

function Start-NativeApp([switch]$ForceBuild) {
    $Exe = Join-Path $Root 'dist\win-x64\GPTOPT.exe'
    $BuildScript = Join-Path $Root 'Build-GPTOPTApp.ps1'
    $ProjectRoot = Join-Path $Root 'src\GPTOPT.App'

    Show-Step 5 'Checking installed application'

    $needsBuild = $ForceBuild -or -not (Test-Path -LiteralPath $Exe)
    if (-not $needsBuild -and (Test-Path -LiteralPath $ProjectRoot)) {
        $exeTime = (Get-Item -LiteralPath $Exe).LastWriteTimeUtc
        $newestSource = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Include *.cs,*.xaml,*.csproj |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($newestSource -and $newestSource.LastWriteTimeUtc -gt $exeTime) { $needsBuild = $true }
    }

    if ($needsBuild) {
        Show-Step 20 'Building the latest native app'
        if (-not (Test-Path -LiteralPath $BuildScript)) { throw "Build script not found: $BuildScript" }

        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if (-not $pwsh) { throw 'PowerShell 7 is required to build GPTOPT. Install PowerShell 7 and run the launcher again.' }

        & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $BuildScript
        if ($LASTEXITCODE -ne 0) { throw "GPTOPT build failed with exit code $LASTEXITCODE." }
    }

    if (-not (Test-Path -LiteralPath $Exe)) { throw "GPTOPT executable not found after build: $Exe" }

    Show-Step 95 'Opening GPTOPT'
    $existing = Get-Process -Name GPTOPT -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        try {
            Add-Type -Namespace Win32 -Name WindowTools -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -ErrorAction SilentlyContinue
            [Win32.WindowTools]::SetForegroundWindow($existing.MainWindowHandle) | Out-Null
        } catch { }
    } else {
        Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe)
    }

    Show-Step 100 'Ready'
    Write-Progress -Activity 'Starting GPTOPT' -Completed
}

try {
    Set-Location -LiteralPath $Root

    switch ($Mode) {
        'gui'     { Start-NativeApp }
        'rebuild' { Start-NativeApp -ForceBuild }
        'legacy'  {
            $Legacy = Join-Path $Root 'HaloSight\scripts\HaloSightGUI.ps1'
            if (-not (Test-Path -LiteralPath $Legacy)) { throw "Legacy GUI not found: $Legacy" }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $Legacy
            exit $LASTEXITCODE
        }
        'test' {
            $SmokeTest = Join-Path $Root 'HaloSight\tests\smoke_test.ps1'
            if (-not (Test-Path -LiteralPath $SmokeTest)) { throw "Smoke test not found: $SmokeTest" }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SmokeTest
            exit $LASTEXITCODE
        }
    }
} catch {
    Write-Progress -Activity 'Starting GPTOPT' -Completed
    Write-Host ''
    Write-Host 'GPTOPT could not start.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Press Enter to close.' -ForegroundColor DarkGray
    [void](Read-Host)
    exit 1
}
