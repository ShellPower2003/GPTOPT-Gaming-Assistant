param(
    [ValidateSet('start','stop','status','report')]
    [string]$Command = 'status'
)

$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $RootDir 'config\halosight.config.json'
$WatchedProcesses = @('HaloInfinite','RTSS','MSIAfterburner','CapFrameX','steam','obs64','SteelSeriesSonar','SteelSeriesEngine','CC_Engine_x64','audiodg','dwm','MsMpEng','GameControllerService','chrome','msedge')
$WatchedServices = @('GamingServices','GamingServicesNet','XblAuthManager','XboxGipSvc','GameInputSvc','Audiosrv','AudioEndpointBuilder','SteamService')

function OK($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function BAD($m){ Write-Host "[BAD]  $m" -ForegroundColor Red }
function ACT($m){ Write-Host "[DO]   $m" -ForegroundColor Yellow }
function INF($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }

function Expand-Env($s){ [Environment]::ExpandEnvironmentVariables($s) }

function Get-CfgValue($Path, $Default){
    $cur = $Cfg
    foreach($part in $Path.Split('.')){
        if($null -eq $cur){ return $Default }
        $prop = $cur.PSObject.Properties[$part]
        if($null -eq $prop){ return $Default }
        $cur = $prop.Value
    }
    if($null -eq $cur){ return $Default }
    return $cur
}

function Resolve-ToolPath($Tool){
    if([string]::IsNullOrWhiteSpace($Tool)){ return $null }
    $expanded = Expand-Env $Tool
    if([IO.Path]::IsPathRooted($expanded) -and (Test-Path -LiteralPath $expanded)){ return $expanded }
    $local = Join-Path $RootDir $expanded
    if(Test-Path -LiteralPath $local){ return $local }
    $cmd = Get-Command $expanded -ErrorAction SilentlyContinue
    if($cmd){ return $cmd.Source }
    return $null
}

function Load-Config {
    if(Test-Path $ConfigPath){
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    throw "Missing config: $ConfigPath"
}

$Cfg = Load-Config
$SessionRoot = Expand-Env $Cfg.SessionRoot
$StatePath = Join-Path $SessionRoot '_active_session.json'
New-Item -ItemType Directory -Force -Path $SessionRoot | Out-Null

function Get-TimerResolutionMs {
    try{
        if(-not ('HS_Timer' -as [type])){
            Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HS_Timer {
    [DllImport("ntdll.dll")] public static extern int NtQueryTimerResolution(out uint min,out uint max,out uint current);
}
"@ -ErrorAction SilentlyContinue
        }
        [uint32]$a=0;[uint32]$b=0;[uint32]$c=0
        [HS_Timer]::NtQueryTimerResolution([ref]$a,[ref]$b,[ref]$c) | Out-Null
        return [math]::Round($c/10000,3)
    }catch{ return $null }
}

function Export-Object($obj, $path){
    try{ $obj | ConvertTo-Json -Depth 8 | Out-File -FilePath $path -Encoding UTF8 }catch{ BAD "Failed writing $path : $($_.Exception.Message)" }
}

function Get-CoreState {
    $hags = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name HwSchMode -ErrorAction SilentlyContinue
    $mpo  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name OverlayTestMode -ErrorAction SilentlyContinue
    $g1   = Get-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled -ErrorAction SilentlyContinue
    $g2   = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name AppCaptureEnabled -ErrorAction SilentlyContinue
    $p    = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    $pendingRename = @($p.PendingFileRenameOperations | Where-Object { $_ -and $_.Trim() -ne '' })
    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        TimerResolutionMs = Get-TimerResolutionMs
        ActivePowerPlan = $(try { ((powercfg /getactivescheme) -join ' ') } catch { $null })
        HAGS = $hags.HwSchMode
        MPOOverlayTestMode = $mpo.OverlayTestMode
        GameDVR_Enabled = $g1.GameDVR_Enabled
        AppCaptureEnabled = $g2.AppCaptureEnabled
        CBSRebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
        WURebootRequired = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
        PendingRenameEntries = $pendingRename
    }
}

function Export-Snapshot($SessionDir, $Tag){
    $SnapDir = Join-Path $SessionDir $Tag
    New-Item -ItemType Directory -Force -Path $SnapDir | Out-Null

    Export-Object (Get-CoreState) (Join-Path $SnapDir 'core_state.json')

    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object CPU -Descending |
        Select-Object -First 80 ProcessName,Id,PriorityClass,CPU,@{n='RAM_MB';e={[math]::Round($_.WorkingSet64/1MB,1)}},Path |
        Export-Csv (Join-Path $SnapDir 'process_top.csv') -NoTypeInformation

    Get-Process $WatchedProcesses -ErrorAction SilentlyContinue |
        Select-Object ProcessName,Id,PriorityClass,CPU,@{n='RAM_MB';e={[math]::Round($_.WorkingSet64/1MB,1)}},Path |
        Export-Csv (Join-Path $SnapDir 'watched_processes.csv') -NoTypeInformation

    Get-Service $WatchedServices -ErrorAction SilentlyContinue |
        Select-Object Name,DisplayName,Status,StartType |
        Export-Csv (Join-Path $SnapDir 'services.csv') -NoTypeInformation

    Get-PnpDevice -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -notin @('OK','Unknown') } |
        Select-Object Status,Class,FriendlyName,InstanceId |
        Export-Csv (Join-Path $SnapDir 'problem_devices.csv') -NoTypeInformation

    Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue |
        Select-Object Name,Status,Manufacturer,DeviceID |
        Export-Csv (Join-Path $SnapDir 'audio_devices.csv') -NoTypeInformation

    Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate |
        Export-Csv (Join-Path $SnapDir 'video_controllers.csv') -NoTypeInformation

    $nvsmi = @(
        "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        "$env:SystemRoot\System32\nvidia-smi.exe",
        'nvidia-smi.exe'
    ) | ForEach-Object { Resolve-ToolPath $_ } | Where-Object { $_ } | Select-Object -First 1
    if($nvsmi){
        try{ & $nvsmi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,power.draw,clocks.gr,clocks.mem,memory.used,memory.total,fan.speed --format=csv,noheader,nounits | Out-File (Join-Path $SnapDir 'nvidia_smi.txt') -Encoding UTF8 }catch{}
    }

    Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddHours(-6)} -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -notmatch 'GoogleChromeElevationService|MicrosoftEdgeElevationService' } |
        Select-Object -First 40 TimeCreated,ProviderName,Id,LevelDisplayName,Message |
        Export-Csv (Join-Path $SnapDir 'recent_system_errors.csv') -NoTypeInformation
}

function Find-NewEvidence($StartTime){
    $items = New-Object System.Collections.Generic.List[object]
    $patterns = @($Cfg.CaptureFilePatterns)
    $maxFiles = [int](Get-CfgValue 'Evidence.MaxFiles' 50)
    $maxMB = [double](Get-CfgValue 'Evidence.MaxFileMB' 1500)
    $excludedNames = @((Get-CfgValue 'Evidence.ExcludeDirectoryNames' @()) | ForEach-Object { [string]$_ })
    foreach($rootRaw in $Cfg.SearchRoots){
        $root = Expand-Env $rootRaw
        if(!(Test-Path $root)){ continue }
        try{
            Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    if($_.LastWriteTime -lt $StartTime){ return $false }
                    if(($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){ return $false }
                    if($maxMB -gt 0 -and ($_.Length / 1MB) -gt $maxMB){ return $false }
                    foreach($name in $excludedNames){
                        if($_.FullName -like "*\$name\*"){ return $false }
                    }
                    foreach($pat in $patterns){
                        if($_.Name -like $pat){ return $true }
                    }
                    return $false
                } |
                Select-Object FullName,Name,Length,LastWriteTime |
                ForEach-Object { $items.Add($_) }
        }catch{
            WARN "Evidence scan skipped root '$root': $($_.Exception.Message)"
        }
    }
    $items |
        Group-Object FullName |
        ForEach-Object { $_.Group | Select-Object -First 1 } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $maxFiles
}

function Copy-Evidence($SessionDir, $StartTime){
    $EvidenceDir = Join-Path $SessionDir 'evidence'
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    $items = @(Find-NewEvidence $StartTime)
    $manifest = @()
    foreach($i in $items){
        $safe = ($i.Name -replace '[^a-zA-Z0-9._() -]','_')
        $dest = Join-Path $EvidenceDir $safe
        $n=1
        while(Test-Path $dest){
            $dest = Join-Path $EvidenceDir ("{0}_{1}{2}" -f [IO.Path]::GetFileNameWithoutExtension($safe),$n,[IO.Path]::GetExtension($safe)); $n++
        }
        try{
            Copy-Item -LiteralPath $i.FullName -Destination $dest -Force
            $manifest += [pscustomobject]@{ Source=$i.FullName; CopiedTo=$dest; SizeMB=[math]::Round($i.Length/1MB,1); LastWriteTime=$i.LastWriteTime }
        }catch{
            $manifest += [pscustomobject]@{ Source=$i.FullName; CopiedTo='COPY_FAILED'; SizeMB=[math]::Round($i.Length/1MB,1); LastWriteTime=$i.LastWriteTime }
        }
    }
    $manifest | Export-Csv (Join-Path $SessionDir 'evidence_manifest.csv') -NoTypeInformation
    return $manifest
}

function Compress-LatestVideo($SessionDir){
    if(-not $Cfg.VideoCompress.Enabled){ return }
    $ff = Resolve-ToolPath $Cfg.OptionalTools.FfmpegExe
    if(!$ff){ WARN 'ffmpeg not found; skipping video compression'; return }
    $ev = Join-Path $SessionDir 'evidence'
    $video = Get-ChildItem $ev -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(mkv|mp4)$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if(!$video){ return }
    $out = Join-Path $SessionDir ("UPLOAD_CLIP_" + $video.BaseName + "_5min_1080p.mp4")
    ACT "Compressing video clip: $($video.Name)"
    & $ff -y -ss 00:00:00 -t ("00:{0:00}:00" -f [int]$Cfg.VideoCompress.MaxMinutes) -i "$($video.FullName)" -vf "scale=$($Cfg.VideoCompress.Resolution),fps=$($Cfg.VideoCompress.FPS)" -c:v h264_nvenc -preset p5 -b:v $($Cfg.VideoCompress.Bitrate) -maxrate 10000k -bufsize 16000k -c:a aac -b:a 128k -movflags +faststart "$out"
    if($LASTEXITCODE -ne 0){
        WARN 'NVENC compression failed; retrying with CPU x264'
        & $ff -y -ss 00:00:00 -t ("00:{0:00}:00" -f [int]$Cfg.VideoCompress.MaxMinutes) -i "$($video.FullName)" -vf "scale=$($Cfg.VideoCompress.Resolution),fps=$($Cfg.VideoCompress.FPS)" -c:v libx264 -preset veryfast -b:v $($Cfg.VideoCompress.Bitrate) -maxrate 10000k -bufsize 16000k -c:a aac -b:a 128k -movflags +faststart "$out"
    }
    if(Test-Path $out){ OK "Compressed clip created: $out" }
}

function New-Report($SessionDir){
    $pre = Join-Path $SessionDir 'start\core_state.json'
    $post = Join-Path $SessionDir 'stop\core_state.json'
    $manifestPath = Join-Path $SessionDir 'evidence_manifest.csv'
    $preObj = if(Test-Path $pre){ Get-Content $pre -Raw | ConvertFrom-Json }else{$null}
    $postObj = if(Test-Path $post){ Get-Content $post -Raw | ConvertFrom-Json }else{$null}
    $manifest = if(Test-Path $manifestPath){ Import-Csv $manifestPath }else{@()}
    $report = Join-Path $SessionDir 'HaloSight_Report.md'
    $lines = @()
    $lines += '# HaloSight Session Report'
    $lines += ''
    $lines += "Session: $(Split-Path -Leaf $SessionDir)"
    $lines += "Generated: $((Get-Date).ToString('o'))"
    $lines += ''
    $lines += '## Core State'
    if($postObj){
        $lines += "- Timer resolution: $($postObj.TimerResolutionMs) ms"
        $lines += "- Power plan: $($postObj.ActivePowerPlan)"
        $lines += "- HAGS value: $($postObj.HAGS)"
        $lines += "- MPO OverlayTestMode: $($postObj.MPOOverlayTestMode)"
        $lines += "- Game DVR: GameDVR_Enabled=$($postObj.GameDVR_Enabled), AppCaptureEnabled=$($postObj.AppCaptureEnabled)"
        $lines += "- CBS reboot pending: $($postObj.CBSRebootPending)"
        $lines += "- Windows Update reboot required: $($postObj.WURebootRequired)"
        $lines += "- Pending rename count: $(@($postObj.PendingRenameEntries).Count)"
    }
    $lines += ''
    $lines += '## Evidence Files'
    if($manifest.Count -gt 0){
        foreach($m in $manifest){ $lines += "- $($m.SizeMB) MB - $($m.Source)" }
    }else{ $lines += '- None copied. Start/stop may not have enclosed a new capture/video file.' }
    $lines += ''
    $lines += '## Notes'
    $lines += '- External-only. No injection, no memory read, no Halo priority change, no browser cleanup.'
    $lines += '- Upload the `_UPLOAD.zip` to ChatGPT for analysis.'
    $lines | Out-File $report -Encoding UTF8
    return $report
}

function Zip-Session($SessionDir){
    $zip = Join-Path (Split-Path -Parent $SessionDir) ((Split-Path -Leaf $SessionDir) + '_UPLOAD.zip')
    if(Test-Path $zip){ Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $SessionDir '*') -DestinationPath $zip -Force
    return $zip
}

function Start-Session {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path $SessionRoot "session_$stamp"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $state = [pscustomobject]@{ SessionDir=$dir; StartTime=(Get-Date).ToString('o'); Project=$Cfg.Project; Version='0.3' }
    Export-Object $state $StatePath
    Export-Object $Cfg (Join-Path $dir 'halosight.config.used.json')
    ACT 'Capturing start snapshot'
    Export-Snapshot $dir 'start'
    OK "Session started: $dir"
    INF 'Play match. Stop CapFrameX/video before scoreboard if possible. Then run HaloSight_STOP.cmd.'
}

function Stop-Session {
    if(!(Test-Path $StatePath)){ BAD 'No active HaloSight session found. Run START first.'; return }
    $state = Get-Content $StatePath -Raw | ConvertFrom-Json
    $dir = $state.SessionDir
    if(!(Test-Path $dir)){ BAD "Session folder missing: $dir"; return }
    $startTime = [datetime]$state.StartTime
    ACT 'Capturing stop snapshot'
    Export-Snapshot $dir 'stop'
    ACT 'Copying new CapFrameX/video/evidence files'
    $manifest = Copy-Evidence $dir $startTime
    OK "Evidence files copied: $(@($manifest).Count)"
    Compress-LatestVideo $dir
    $report = New-Report $dir
    OK "Report created: $report"
    $zip = Zip-Session $dir
    OK "Upload package: $zip"
    Remove-Item $StatePath -Force -ErrorAction SilentlyContinue
}

function Show-Status {
    Write-Host "`n=== GPTOPT HALOSIGHT STATUS ===`n" -ForegroundColor Cyan
    if(Test-Path $StatePath){
        $s = Get-Content $StatePath -Raw | ConvertFrom-Json
        OK "Active session: $($s.SessionDir)"
        INF "Started: $($s.StartTime)"
    }else{ WARN 'No active session' }
    Write-Host "`nCore:" -ForegroundColor Cyan
    Get-CoreState | Format-List
    Write-Host "`nWatched processes:" -ForegroundColor Cyan
    Get-Process $WatchedProcesses -ErrorAction SilentlyContinue |
        Select ProcessName,Id,PriorityClass,@{n='RAM_MB';e={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
}

switch($Command){
    'start' { Start-Session }
    'stop' { Stop-Session }
    'status' { Show-Status }
    'report' {
        $last = Get-ChildItem $SessionRoot -Directory -Filter 'session_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if($last){ New-Report $last.FullName | ForEach-Object { OK "Report updated: $_" }; Zip-Session $last.FullName | ForEach-Object { OK "Upload package: $_" } }else{ BAD 'No sessions found' }
    }
}
