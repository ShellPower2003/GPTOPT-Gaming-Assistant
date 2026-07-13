[CmdletBinding()]
param(
    [ValidateSet('gui','legacy','test','rebuild')]
    [string]$Mode = 'gui'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$Root = Split-Path -Parent $PSCommandPath
$TargetBranch = 'agent/native-desktop-app'

function Show-Step([int]$Percent, [string]$Status) {
    Write-Progress -Activity 'Starting GPTOPT' -Status "$Percent% - $Status" -PercentComplete $Percent
    Write-Host "[$Percent%] $Status" -ForegroundColor Cyan
}

function Get-Git {
    Get-Command git.exe -ErrorAction SilentlyContinue
}

function Remove-GeneratedState {
    $generated = @(
        (Join-Path $Root 'src\GPTOPT.App\bin'),
        (Join-Path $Root 'src\GPTOPT.App\obj')
    )
    foreach ($path in $generated) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Older builds patched this tracked XAML file at build time. Restore it before updating.
    $git = Get-Git
    if ($git -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        & $git.Source -C $Root restore --source=HEAD --worktree -- 'src/GPTOPT.App/MainWindow.xaml' 2>$null
    }
}

function Update-GPTOPTSource {
    $git = Get-Git
    if (-not $git -or -not (Test-Path -LiteralPath (Join-Path $Root '.git'))) { return $false }

    Show-Step 8 'Cleaning generated build state'
    Remove-GeneratedState

    Show-Step 12 'Checking for GPTOPT updates'
    $dirtyLines = @(& $git.Source -C $Root status --porcelain 2>$null)
    $realChanges = @($dirtyLines | Where-Object {
        $_ -and
        $_ -notmatch 'src/GPTOPT\.App/(bin|obj)/' -and
        $_ -notmatch '^\?\? dist/' -and
        $_ -notmatch '^\?\? (Backups|Logs|Reports)/'
    })

    if ($realChanges.Count -gt 0) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Show-Step 15 'Protecting local source changes'
        & $git.Source -C $Root stash push --include-untracked -m "GPTOPT launcher backup $stamp" | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Unable to protect local repository changes.' }
    }

    & $git.Source -C $Root fetch origin $TargetBranch --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Unable to fetch the latest GPTOPT source.' }

    $branch = (& $git.Source -C $Root branch --show-current 2>$null).Trim()
    if ($branch -ne $TargetBranch) {
        & $git.Source -C $Root switch $TargetBranch --quiet
        if ($LASTEXITCODE -ne 0) { throw "Unable to switch to $TargetBranch." }
    }

    $before = (& $git.Source -C $Root rev-parse HEAD).Trim()
    & $git.Source -C $Root merge --ff-only "origin/$TargetBranch" --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Unable to fast-forward GPTOPT to the latest version.' }
    $after = (& $git.Source -C $Root rev-parse HEAD).Trim()

    return $before -ne $after
}

function Start-NativeApp([switch]$ForceBuild) {
    $Exe = Join-Path $Root 'dist\win-x64\GPTOPT.exe'
    $BuildScript = Join-Path $Root 'Build-GPTOPTApp.ps1'
    $BuildStamp = Join-Path $Root 'dist\win-x64\.gptopt-build-commit'
    $git = Get-Git

    $updated = Update-GPTOPTSource
    Show-Step 20 'Checking installed application'

    $head = $null
    if ($git -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        $head = (& $git.Source -C $Root rev-parse HEAD 2>$null).Trim()
    }
    $builtCommit = if (Test-Path -LiteralPath $BuildStamp) { (Get-Content -Raw -LiteralPath $BuildStamp).Trim() } else { '' }

    $needsBuild = $ForceBuild -or $updated -or -not (Test-Path -LiteralPath $Exe) -or -not $head -or ($builtCommit -ne $head)

    if ($needsBuild) {
        Show-Step 30 'Building the latest native app'
        if (-not (Test-Path -LiteralPath $BuildScript)) { throw "Build script not found: $BuildScript" }

        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if (-not $pwsh) { throw 'PowerShell 7 is required to build GPTOPT.' }

        Stop-Process -Name GPTOPT -Force -ErrorAction SilentlyContinue
        & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $BuildScript
        if ($LASTEXITCODE -ne 0) { throw "GPTOPT build failed with exit code $LASTEXITCODE." }

        if (-not (Test-Path -LiteralPath $Exe)) { throw "GPTOPT executable not found after build: $Exe" }
        Set-Content -LiteralPath $BuildStamp -Value $head -Encoding ascii -Force

        # Remove build-generated repository dirt so future updates are never blocked.
        Remove-GeneratedState
    }

    if (-not (Test-Path -LiteralPath $Exe)) { throw "GPTOPT executable not found: $Exe" }

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
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $Legacy
            exit $LASTEXITCODE
        }
        'test' {
            $SmokeTest = Join-Path $Root 'HaloSight\tests\smoke_test.ps1'
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
