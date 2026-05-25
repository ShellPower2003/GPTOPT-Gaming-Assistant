param(
    [switch]$StartMenu
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell

$targets = @(
    @{ Name='GPTOPT Control Center'; Target='App\GPTOPT-Control.cmd' },
    @{ Name='GPTOPT Read Only Audit'; Target='App\GPTOPT-ReadOnly.cmd' },
    @{ Name='GPTOPT HaloSight GUI'; Target='App\GPTOPT-HaloSight.cmd' },
    @{ Name='GPTOPT Normal Recommendations'; Target='App\GPTOPT-Recommend.cmd' },
    @{ Name='GPTOPT Full Preview Queue'; Target='App\GPTOPT-PreviewQueue.cmd' },
    @{ Name='GPTOPT Report Bundle'; Target='App\GPTOPT-Report.cmd' },
    @{ Name='GPTOPT Safety Scan'; Target='App\GPTOPT-SafetyScan.cmd' }
)

$locations = @($desktop)

if ($StartMenu) {
    $start = Join-Path ([Environment]::GetFolderPath('Programs')) 'GPTOPT'
    New-Item -ItemType Directory -Force -Path $start | Out-Null
    $locations += $start
}

foreach ($loc in $locations) {
    foreach ($item in $targets) {
        $targetPath = Join-Path $repo $item.Target
        if (!(Test-Path -LiteralPath $targetPath)) {
            Write-Warning "Skipping missing launcher: $targetPath"
            continue
        }

        $lnk = Join-Path $loc "$($item.Name).lnk"
        $shortcut = $shell.CreateShortcut($lnk)
        $shortcut.TargetPath = $targetPath
        $shortcut.WorkingDirectory = $repo
        $shortcut.IconLocation = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe,0"
        $shortcut.Description = $item.Name
        $shortcut.Save()

        Write-Host "[OK] $lnk"
    }
}
