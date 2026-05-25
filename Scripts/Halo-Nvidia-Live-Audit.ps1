$ErrorActionPreference='SilentlyContinue'
Clear-Host
Write-Host "`n=== HALO / NVIDIA LIVE AUDIT ===" -ForegroundColor Cyan
Write-Host "Read-only. No reboot. No changes.`n" -ForegroundColor Green

function Section($m){Write-Host "`n--- $m ---" -ForegroundColor Yellow}
function Val($n,$v){Write-Host (("{0,-34}: {1}" -f $n,$v))}
function Reg($p,$n){try{(Get-ItemProperty -Path $p -Name $n -ErrorAction Stop).$n}catch{'Not set'}}

Section 'OS / CPU / GPU'
$cv='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Val 'Windows Product' (Reg $cv 'ProductName')
Val 'DisplayVersion' (Reg $cv 'DisplayVersion')
Val 'CurrentBuild' (Reg $cv 'CurrentBuild')
Val 'UBR' (Reg $cv 'UBR')
Get-CimInstance Win32_Processor | Select-Object -First 1 Name,NumberOfCores,NumberOfLogicalProcessors | Format-List
Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate | Format-Table -AutoSize

Section 'Power / HAGS / MPO / Game DVR'
Val 'Power plan' ((powercfg /getactivescheme) -join ' ')
Val 'HAGS HwSchMode' (Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode')
Val 'MPO OverlayTestMode' (Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode')
Val 'GameDVR AppCaptureEnabled' (Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled')
Val 'GameBar AutoGameModeEnabled' (Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled')
Val 'GameBar ShowStartupPanel' (Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel')

Section 'DirectX User Global Settings'
Val 'DirectXUserGlobalSettings' (Reg 'HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings')

Section 'Halo Config Files'
$haloDirs=@(
 "$env:LOCALAPPDATA\HaloInfinite\Settings",
 "$env:USERPROFILE\AppData\Local\HaloInfinite\Settings"
) | Select-Object -Unique
foreach($d in $haloDirs){
 if(Test-Path $d){
  Write-Host "FOUND: $d" -ForegroundColor Green
  Get-ChildItem $d -File | Select Name,Length,LastWriteTime | Format-Table -AutoSize
  $spec=Join-Path $d 'SpecControlSettings.json'
  if(Test-Path $spec){
   Write-Host "`nSpecControlSettings.json preview:" -ForegroundColor Cyan
   Get-Content $spec -Raw | Select-Object -First 1
  }
 } else { Write-Host "MISSING: $d" -ForegroundColor DarkGray }
}

Section 'Steam Halo Path'
$steam=(Reg 'HKCU:\Software\Valve\Steam' 'SteamPath')
Val 'SteamPath' $steam
$possible=@(
 'C:\Program Files (x86)\Steam\steamapps\common\Halo Infinite\game\HaloInfinite.exe',
 'C:\Program Files (x86)\Steam\steamapps\common\Halo Infinite\HaloInfinite.exe'
)
foreach($p in $possible){Val $p (Test-Path $p)}

Section 'Running Game / Tools / Overlays'
Get-Process HaloInfinite,steam,RTSS,MSIAfterburner,CapFrameX,PresentMon,Discord,nvcontainer,NVIDIA*,dwm,audiodg -ErrorAction SilentlyContinue |
 Select ProcessName,Id,PriorityClass,CPU,@{n='RAM_MB';e={[math]::Round($_.WorkingSet64/1MB,1)}},Path |
 Sort ProcessName |
 Format-Table -AutoSize

Section 'NVIDIA SMI Snapshot'
$nvsmi=(Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue).Source
if($nvsmi){
 & $nvsmi --query-gpu=name,driver_version,pstate,utilization.gpu,utilization.memory,power.draw,clocks.gr,clocks.mem,temperature.gpu,memory.used --format=csv
} else { Write-Host 'nvidia-smi not found' -ForegroundColor Red }

Section 'Defender Exclusions Relevant To Halo'
$mp=Get-MpPreference
$mp.ExclusionProcess | Where-Object {$_ -match 'Halo|RTSS|MSIAfterburner|CapFrameX|PresentMon|Steam'} | Sort | ForEach-Object {Val 'Process exclusion' $_}
$mp.ExclusionPath | Where-Object {$_ -match 'Halo|Steam|CapFrameX|PresentMon'} | Sort | ForEach-Object {Val 'Path exclusion' $_}

Section 'NPI / Profile Inspector Locations'
$roots=@($env:USERPROFILE,'C:\','D:\') | Where-Object {Test-Path $_}
foreach($r in $roots){
 Get-ChildItem -Path $r -Filter '*ProfileInspector*.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 10 FullName,LastWriteTime | Format-Table -AutoSize
}

Section 'Quick Verdict'
Write-Host 'Post this output back. Next step is NPI profile cleanup + Halo competitive preset based on actual state.' -ForegroundColor Green
