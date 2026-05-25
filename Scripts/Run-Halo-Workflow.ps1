$ErrorActionPreference = 'SilentlyContinue'
Clear-Host
Write-Host "`n=== GPTOPT HALO LOCAL WORKFLOW ===" -ForegroundColor Cyan
Write-Host "Runs local audit, applies Halo config baseline, saves a report. No reboot.`n" -ForegroundColor Green

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReportDir = Join-Path $Root 'Reports'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Report = Join-Path $ReportDir "Halo-Workflow_$Stamp.txt"

function Add-Line($m){ Write-Host $m; Add-Content -Path $Report -Value $m }
function Section($m){ Add-Line "`n=== $m ===" }
function Reg($p,$n){ try{ (Get-ItemProperty -Path $p -Name $n -ErrorAction Stop).$n } catch { 'Not set' } }

Section 'GPTOPT HALO WORKFLOW REPORT'
Add-Line "Time: $(Get-Date)"
Add-Line "Repo: $Root"
Add-Line "Report: $Report"

Section 'SYSTEM SNAPSHOT'
$cv='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Add-Line "Windows: $(Reg $cv 'ProductName') $(Reg $cv 'DisplayVersion') build $(Reg $cv 'CurrentBuild').$(Reg $cv 'UBR')"
$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1 Name,NumberOfCores,NumberOfLogicalProcessors
Add-Line "CPU: $($cpu.Name) / $($cpu.NumberOfCores)c $($cpu.NumberOfLogicalProcessors)t"
$gpu=Get-CimInstance Win32_VideoController | Where-Object {$_.Name -match 'NVIDIA'} | Select-Object -First 1 Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate
Add-Line "GPU: $($gpu.Name) / Driver $($gpu.DriverVersion)"
Add-Line "Display: $($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution) @ $($gpu.CurrentRefreshRate) Hz"
Add-Line "Power: $((powercfg /getactivescheme) -join ' ')"
Add-Line "HAGS HwSchMode: $(Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode')"
Add-Line "MPO OverlayTestMode: $(Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode')"
Add-Line "GameDVR Enabled: $(Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled')"
Add-Line "Game Mode: $(Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled')"
Add-Line "DirectX Global: $(Reg 'HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings')"

Section 'APPLY HALO CONFIG BASELINE'
$apply = Join-Path $Root 'Scripts\Apply-Halo-Competitive-Quality-Baseline.ps1'
if(Test-Path $apply){
    Add-Line "Running: $apply"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $apply | Tee-Object -FilePath $Report -Append
} else {
    Add-Line "Missing baseline script: $apply"
}

Section 'POST-BASELINE HALO CONFIG SUMMARY'
$spec = Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings\SpecControlSettings.json'
if(Test-Path $spec){
    $j=Get-Content $spec -Raw | ConvertFrom-Json
    Add-Line "Resolution X: $($j.spec_control_windowed_display_resolution_x.value)"
    Add-Line "Resolution Y: $($j.spec_control_windowed_display_resolution_y.value)"
    Add-Line "Resolution scale: $($j.spec_control_resolution_scale.value)"
    Add-Line "Minimum FPS: $($j.spec_control_minimum_framerate.value)"
    Add-Line "Target FPS: $($j.spec_control_target_framerate.value)"
    Add-Line "VSync: $($j.spec_control_vsync.value)"
    Add-Line "HDR/WCG: $($j.spec_control_hdr_wcg.value)"
    Add-Line "Reflections: $($j.spec_control_reflections.value)"
    Add-Line "HLOD: $($j.spec_control_hlod.value)"
    Add-Line "Assets: $($j.spec_control_asset_category_level.value)"
} else {
    Add-Line "Halo config not found: $spec"
}

Section 'RUNNING PROCESS SNAPSHOT'
Get-Process HaloInfinite,RTSS,MSIAfterburner,steam,dwm,audiodg,Discord,CapFrameX,PresentMon -ErrorAction SilentlyContinue |
    Select ProcessName,Id,PriorityClass,CPU,@{n='RAM_MB';e={[math]::Round($_.WorkingSet64/1MB,1)}} |
    Sort ProcessName |
    Format-Table -AutoSize | Out-String | Tee-Object -FilePath $Report -Append | Write-Host

Section 'NVIDIA SMI SNAPSHOT'
$nvsmi=(Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue).Source
if($nvsmi){
    & $nvsmi --query-gpu=name,driver_version,pstate,utilization.gpu,utilization.memory,power.draw,clocks.gr,clocks.mem,temperature.gpu,memory.used --format=csv | Tee-Object -FilePath $Report -Append
} else {
    Add-Line 'nvidia-smi not found'
}

Section 'LOCAL DECISION'
Add-Line 'Baseline target: RTSS 240 cap, Halo Reflex ON first, then ON+Boost comparison.'
Add-Line 'NPI experimental settings: leave unchanged until a clean benchmark exists.'
Add-Line 'If Discord is present in the process snapshot, close it before a serious benchmark.'
Add-Line 'If Halo is not running, launch Halo and run this script again after one route/match.'

Write-Host "`nSaved report:" -ForegroundColor Cyan
Write-Host $Report -ForegroundColor Green
Start-Process notepad.exe $Report
