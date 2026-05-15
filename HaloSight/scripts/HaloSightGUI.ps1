param([switch]$OpenSettings)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$Root = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $PSScriptRoot "HaloSight.ps1"
$SettingsScript = Join-Path $PSScriptRoot "HaloSightSettings.ps1"
. $SettingsScript

$Config = Get-HaloSightConfig
$SessionRoot = [Environment]::ExpandEnvironmentVariables($Config.SessionRoot)

function Reload-HSConfig {
    $script:Config = Get-HaloSightConfig
    $script:SessionRoot = [Environment]::ExpandEnvironmentVariables($script:Config.SessionRoot)
}

function Get-LatestSessionPath {
    Reload-HSConfig
    if(!(Test-Path $SessionRoot)){ return $null }
    $d = Get-ChildItem $SessionRoot -Directory -Filter "session_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($d){ return $d.FullName }
    return $null
}

function Get-LatestUploadZip {
    Reload-HSConfig
    if(!(Test-Path $SessionRoot)){ return $null }
    $z = Get-ChildItem $SessionRoot -File -Filter "*_UPLOAD.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($z){ return $z.FullName }
    return $null
}

function Get-HaloSightTimerResolutionMs {
    try{
        if(-not ('HSGUI_Timer' -as [type])){
            Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HSGUI_Timer {
    [DllImport("ntdll.dll")] public static extern int NtQueryTimerResolution(out uint min,out uint max,out uint current);
}
"@ -ErrorAction SilentlyContinue
        }
        [uint32]$a=0;[uint32]$b=0;[uint32]$c=0
        [HSGUI_Timer]::NtQueryTimerResolution([ref]$a,[ref]$b,[ref]$c) | Out-Null
        return [math]::Round($c/10000,3)
    }catch{ return $null }
}

function Test-HaloSightProcess {
    param([string[]]$Names)
    $found = @(Get-Process $Names -ErrorAction SilentlyContinue)
    return [pscustomobject]@{ Count=$found.Count; Names=@($found | Select-Object -ExpandProperty ProcessName -Unique) }
}

function New-HaloSightCardState($Title, $State, $Detail){
    [pscustomobject]@{ Title=$Title; State=$State; Detail=$Detail }
}

function Get-GPTOPTCommandPath {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if($cmd){ return $cmd.Source }
    return $null
}

function Resolve-GPTOPTNvidiaProfileInspectorPath {
    Reload-HSConfig
    $override = $Config.OptionalTools.NvidiaProfileInspectorPath
    if(-not [string]::IsNullOrWhiteSpace($override)){
        $expanded = [Environment]::ExpandEnvironmentVariables($override)
        if(Test-Path -LiteralPath $expanded){ return $expanded }
        return $expanded
    }
    $cmd = Get-GPTOPTCommandPath 'nvidiaProfileInspector.exe'
    if($cmd){ return $cmd }
    $local = Join-Path $Root 'tools\nvidiaProfileInspector.exe'
    if(Test-Path -LiteralPath $local){ return $local }
    return $null
}

function Get-GPTOPTRegistryValue {
    param([string]$Path, [string]$Name)
    try{
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }catch{
        return $null
    }
}

function Get-GPTOPTActiveDisplayText {
    try{
        $primary = [System.Windows.Forms.Screen]::PrimaryScreen
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
        $refresh = if($gpu -and $gpu.CurrentRefreshRate){ "$($gpu.CurrentRefreshRate)Hz" }else{ 'refresh unknown' }
        if($primary){
            return "$($primary.Bounds.Width)x$($primary.Bounds.Height) @ $refresh"
        }
    }catch{}
    return 'Unavailable'
}

function Get-GPTOPTNvidiaDisplayState {
    Reload-HSConfig
    $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1)
    $smiPath = Get-GPTOPTCommandPath 'nvidia-smi.exe'
    $npiPath = Resolve-GPTOPTNvidiaProfileInspectorPath
    $npiExists = -not [string]::IsNullOrWhiteSpace($npiPath) -and (Test-Path -LiteralPath $npiPath)
    $rtss = Test-HaloSightProcess @('RTSS')
    $afterburner = Test-HaloSightProcess @('MSIAfterburner')
    $hags = Get-GPTOPTRegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    $mpo = Get-GPTOPTRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'

    [pscustomobject]@{
        NvidiaGpuDetected = $gpu.Count -gt 0
        NvidiaGpuName = if($gpu.Count -gt 0){ $gpu[0].Name }else{ 'Not detected' }
        DriverVersion = if($gpu.Count -gt 0 -and $gpu[0].DriverVersion){ $gpu[0].DriverVersion }else{ 'Unavailable' }
        NvidiaSmiPath = if($smiPath){ $smiPath }else{ 'Not found' }
        NvidiaSmiAvailable = [bool]$smiPath
        NvidiaProfileInspectorPath = if($npiPath){ $npiPath }else{ 'Not found' }
        NvidiaProfileInspectorAvailable = $npiExists
        HagsValue = if($null -ne $hags){ [string]$hags }else{ 'Not set' }
        MpoValue = if($null -ne $mpo){ [string]$mpo }else{ 'Not set' }
        ActiveDisplay = Get-GPTOPTActiveDisplayText
        RtssRunning = $rtss.Count -gt 0
        RtssDetail = if($rtss.Count -gt 0){ 'Running' }else{ 'Not detected' }
        AfterburnerRunning = $afterburner.Count -gt 0
        AfterburnerDetail = if($afterburner.Count -gt 0){ 'Running' }else{ 'Not detected' }
    }
}

function Get-HaloSightDashboardState {
    Reload-HSConfig
    $statePath = Join-Path $SessionRoot '_active_session.json'
    $active = Test-Path -LiteralPath $statePath
    $latestZip = Get-LatestUploadZip
    $latestSession = Get-LatestSessionPath
    $timer = Get-HaloSightTimerResolutionMs
    $halo = Test-HaloSightProcess @('HaloInfinite')
    $rtss = Test-HaloSightProcess @('RTSS')
    $afterburner = Test-HaloSightProcess @('MSIAfterburner')
    $capFrameX = Test-HaloSightProcess @('CapFrameX')
    $obs = Test-HaloSightProcess @('obs64','obs')
    $sonar = Test-HaloSightProcess @('SteelSeriesSonar','SteelSeriesEngine','audiodg')
    $services = @(Get-Service @($Config.WatchedServices) -ErrorAction SilentlyContinue)
    $runningServices = @($services | Where-Object { $_.Status -eq 'Running' })
    $problemDevices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Status -notin @('OK','Unknown') })
    $cbsPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $wuPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $renameRaw = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    $renameCount = @($renameRaw.PendingFileRenameOperations | Where-Object { $_ -and $_.Trim() -ne '' }).Count

    $serviceState = if($services.Count -eq 0){ 'UNKNOWN' }elseif($runningServices.Count -eq $services.Count){ 'GOOD' }elseif($runningServices.Count -gt 0){ 'WARN' }else{ 'BAD' }
    $timerState = if($null -eq $timer){ 'UNKNOWN' }elseif($timer -le 1.1){ 'GOOD' }elseif($timer -le 5){ 'WARN' }else{ 'BAD' }
    $rebootState = if($cbsPending -or $wuPending -or $renameCount -gt 0){ 'WARN' }else{ 'GOOD' }
    $uploadState = if($latestZip){ 'GOOD' }else{ 'UNKNOWN' }
    $nvidia = Get-GPTOPTNvidiaDisplayState

    [pscustomobject]@{
        ActiveSession = $active
        LatestUploadZip = $latestZip
        LatestSession = $latestSession
        Cards = @(
            (New-HaloSightCardState 'Active Session' ($(if($active){'GOOD'}else{'UNKNOWN'})) ($(if($active){'Running'}else{'None'})))
            (New-HaloSightCardState 'Halo' ($(if($halo.Count -gt 0){'GOOD'}else{'UNKNOWN'})) ($(if($halo.Count -gt 0){"$($halo.Count) process(es)"}else{'Not running'})))
            (New-HaloSightCardState 'RTSS' ($(if($rtss.Count -gt 0){'GOOD'}else{'WARN'})) ($(if($rtss.Count -gt 0){'Running'}else{'Not detected'})))
            (New-HaloSightCardState 'MSI Afterburner' ($(if($afterburner.Count -gt 0){'GOOD'}else{'WARN'})) ($(if($afterburner.Count -gt 0){'Running'}else{'Not detected'})))
            (New-HaloSightCardState 'CapFrameX' ($(if($capFrameX.Count -gt 0){'GOOD'}else{'WARN'})) ($(if($capFrameX.Count -gt 0){'Running'}else{'Not detected'})))
            (New-HaloSightCardState 'OBS' ($(if($obs.Count -gt 0){'GOOD'}else{'UNKNOWN'})) ($(if($obs.Count -gt 0){'Running'}else{'Not detected'})))
            (New-HaloSightCardState 'Timer Resolution' $timerState ($(if($null -ne $timer){"$timer ms"}else{'Unavailable'})))
            (New-HaloSightCardState 'Gaming Services' $serviceState ("$($runningServices.Count)/$($services.Count) running"))
            (New-HaloSightCardState 'Audio/Sonar' ($(if($sonar.Count -gt 0){'GOOD'}else{'UNKNOWN'})) ($(if($sonar.Count -gt 0){($sonar.Names -join ', ')}else{'Not detected'})))
            (New-HaloSightCardState 'Problem Devices' ($(if($problemDevices.Count -eq 0){'GOOD'}else{'WARN'})) ("$($problemDevices.Count) issue(s)"))
            (New-HaloSightCardState 'Pending Reboot/Rename' $rebootState ("CBS=$cbsPending WU=$wuPending Rename=$renameCount"))
            (New-HaloSightCardState 'Latest Upload Zip' $uploadState ($(if($latestZip){Split-Path -Leaf $latestZip}else{'None'})))
            (New-HaloSightCardState 'NVIDIA GPU' ($(if($nvidia.NvidiaGpuDetected){'GOOD'}else{'UNKNOWN'})) $nvidia.NvidiaGpuName)
            (New-HaloSightCardState 'NVIDIA Driver' ($(if($nvidia.DriverVersion -ne 'Unavailable'){'GOOD'}else{'UNKNOWN'})) $nvidia.DriverVersion)
            (New-HaloSightCardState 'NVIDIA Profile Inspector' ($(if($nvidia.NvidiaProfileInspectorAvailable){'GOOD'}else{'UNKNOWN'})) $nvidia.NvidiaProfileInspectorPath)
        )
    }
}

function ConvertTo-Multiline($items){
    return (@($items) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`r`n"
}

function ConvertFrom-Multiline($text){
    return @($text -split "(`r`n|`n|;)" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function New-Label($text, $row){
    $label = New-Object Windows.Controls.TextBlock
    $label.Text = $text
    $label.Foreground = '#E5E7EB'
    $label.Margin = '0,6,10,4'
    [Windows.Controls.Grid]::SetRow($label, $row)
    [Windows.Controls.Grid]::SetColumn($label, 0)
    return $label
}

function New-TextBox($text, $row, $multi){
    $box = New-Object Windows.Controls.TextBox
    $box.Text = $text
    $box.Margin = '0,4,0,4'
    $box.Background = '#020617'
    $box.Foreground = '#E5E7EB'
    $box.BorderBrush = '#334155'
    if($multi){
        $box.AcceptsReturn = $true
        $box.TextWrapping = 'Wrap'
        $box.VerticalScrollBarVisibility = 'Auto'
        $box.MinHeight = 72
    }
    [Windows.Controls.Grid]::SetRow($box, $row)
    [Windows.Controls.Grid]::SetColumn($box, 1)
    return $box
}

function New-CheckBox($text, $checked, $row){
    $box = New-Object Windows.Controls.CheckBox
    $box.Content = $text
    $box.IsChecked = [bool]$checked
    $box.Foreground = '#E5E7EB'
    $box.Margin = '0,6,0,4'
    [Windows.Controls.Grid]::SetRow($box, $row)
    [Windows.Controls.Grid]::SetColumn($box, 1)
    return $box
}

function Show-SettingsWindow {
    Reload-HSConfig
    $settings = New-Object Windows.Window
    $settings.Title = 'HaloSight Settings'
    $settings.Width = 780
    $settings.Height = 760
    $settings.WindowStartupLocation = 'CenterOwner'
    $settings.Background = '#111827'

    $dock = New-Object Windows.Controls.DockPanel
    $dock.Margin = '14'
    $settings.Content = $dock

    $buttons = New-Object Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'
    $buttons.HorizontalAlignment = 'Right'
    $buttons.Margin = '0,10,0,0'
    [Windows.Controls.DockPanel]::SetDock($buttons, 'Bottom')
    $dock.Children.Add($buttons) | Out-Null

    $scroll = New-Object Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $dock.Children.Add($scroll) | Out-Null

    $grid = New-Object Windows.Controls.Grid
    $scroll.Content = $grid
    $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = '190' }))
    $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{ Width = '*' }))
    for($i=0; $i -lt 12; $i++){ $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition -Property @{ Height = 'Auto' })) }

    $sessionRootBox = New-TextBox $Config.SessionRoot 0 $false
    $searchRootsBox = New-TextBox (ConvertTo-Multiline $Config.SearchRoots) 1 $true
    $maxFilesBox = New-TextBox ([string]$Config.Evidence.MaxFiles) 2 $false
    $maxFileMbBox = New-TextBox ([string]$Config.Evidence.MaxFileMB) 3 $false
    $copyVideosBox = New-CheckBox 'Copy video evidence files' $Config.Evidence.CopyVideos 4
    $compressVideosBox = New-CheckBox 'Compress latest copied video when ffmpeg is available' $Config.VideoCompress.Enabled 5
    $autoCopyBox = New-CheckBox 'Auto-copy latest upload zip path after Stop/Report' $Config.UI.AutoCopyUploadZipPath 6
    $autoOpenBox = New-CheckBox 'Auto-open upload folder after Stop/Report' $Config.UI.AutoOpenUploadFolder 7
    $watchedProcessesBox = New-TextBox (ConvertTo-Multiline $Config.WatchedProcesses) 8 $true
    $watchedServicesBox = New-TextBox (ConvertTo-Multiline $Config.WatchedServices) 9 $true

    @(
        (New-Label 'Session root' 0), $sessionRootBox,
        (New-Label 'Evidence folders' 1), $searchRootsBox,
        (New-Label 'Max evidence files' 2), $maxFilesBox,
        (New-Label 'Max file size MB' 3), $maxFileMbBox,
        (New-Label 'Copy videos' 4), $copyVideosBox,
        (New-Label 'Compress videos' 5), $compressVideosBox,
        (New-Label 'Auto-copy upload zip' 6), $autoCopyBox,
        (New-Label 'Auto-open upload folder' 7), $autoOpenBox,
        (New-Label 'Watched processes' 8), $watchedProcessesBox,
        (New-Label 'Watched services' 9), $watchedServicesBox
    ) | ForEach-Object { $grid.Children.Add($_) | Out-Null }

    $save = New-Object Windows.Controls.Button
    $save.Content = 'Save Settings'
    $save.Margin = '6'
    $reset = New-Object Windows.Controls.Button
    $reset.Content = 'Reset Defaults'
    $reset.Margin = '6'
    $validate = New-Object Windows.Controls.Button
    $validate.Content = 'Validate Setup'
    $validate.Margin = '6'
    $close = New-Object Windows.Controls.Button
    $close.Content = 'Close'
    $close.Margin = '6'
    @($save,$reset,$validate,$close) | ForEach-Object { $buttons.Children.Add($_) | Out-Null }

    $save.Add_Click({
        try{
            $newConfig = Get-HaloSightConfig
            $newConfig.SessionRoot = $sessionRootBox.Text.Trim()
            $newConfig.SearchRoots = @(ConvertFrom-Multiline $searchRootsBox.Text)
            $newConfig.Evidence.MaxFiles = [int]$maxFilesBox.Text
            $newConfig.Evidence.MaxFileMB = [double]$maxFileMbBox.Text
            $newConfig.Evidence.CopyVideos = [bool]$copyVideosBox.IsChecked
            $newConfig.VideoCompress.Enabled = [bool]$compressVideosBox.IsChecked
            $newConfig.UI.AutoCopyUploadZipPath = [bool]$autoCopyBox.IsChecked
            $newConfig.UI.AutoOpenUploadFolder = [bool]$autoOpenBox.IsChecked
            $newConfig.WatchedProcesses = @(ConvertFrom-Multiline $watchedProcessesBox.Text)
            $newConfig.WatchedServices = @(ConvertFrom-Multiline $watchedServicesBox.Text)
            $result = Test-HaloSightConfig $newConfig
            if(-not $result.IsValid){ throw ($result.Errors -join "`r`n") }
            Save-HaloSightConfig $newConfig | Out-Null
            Reload-HSConfig
            [Windows.MessageBox]::Show('Settings saved.', 'HaloSight Settings') | Out-Null
        }catch{
            [Windows.MessageBox]::Show($_.Exception.Message, 'Settings Error') | Out-Null
        }
    })

    $reset.Add_Click({
        Reset-HaloSightConfig | Out-Null
        [Windows.MessageBox]::Show('Defaults restored. Reopen Settings to view the reset values.', 'HaloSight Settings') | Out-Null
        Reload-HSConfig
    })

    $validate.Add_Click({
        $result = Test-HaloSightConfig
        $msg = if($result.IsValid){ 'Setup is valid.' }else{ "Errors:`r`n" + ($result.Errors -join "`r`n") }
        if($result.Warnings.Count -gt 0){ $msg += "`r`n`r`nWarnings:`r`n" + ($result.Warnings -join "`r`n") }
        [Windows.MessageBox]::Show($msg, 'HaloSight Validation') | Out-Null
    })

    $close.Add_Click({ $settings.Close() })
    $settings.Owner = $window
    $settings.ShowDialog() | Out-Null
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GPTOPT Control Center v0.5" Height="860" Width="1240"
        WindowStartupLocation="CenterScreen" Background="#111827">
  <DockPanel Margin="14">
    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
      <TextBlock Text="GPTOPT Control Center" Foreground="#F9FAFB" FontSize="26" FontWeight="Bold"/>
      <TextBlock Text="Audit-first gaming control center. Read-only NVIDIA / Display foundation. HaloSight remains external capture only." Foreground="#CBD5E1" FontSize="13"/>
    </StackPanel>

    <TextBlock Name="Footer" DockPanel.Dock="Bottom" Foreground="#94A3B8" Margin="0,8,0,0"
               Text="Flow: Ready for Halo? -> Start Session -> play/capture match -> Stop + Build Upload -> send _UPLOAD.zip"/>

    <TabControl Name="MainTabs" Background="#111827" BorderBrush="#334155">
      <TabItem Header="Dashboard">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,10,0,0">
            <UniformGrid Name="DashboardGrid" Columns="3" Margin="0,0,0,10"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="HaloSight">
        <Grid Margin="0,10,0,0">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="44"/><RowDefinition Height="44"/>
            </Grid.RowDefinitions>

            <Button Name="ReadyBtn" Grid.Row="0" Grid.Column="0" Margin="4" Content="Ready for Halo?" FontWeight="Bold"/>
            <Button Name="RefreshBtn" Grid.Row="0" Grid.Column="1" Margin="4" Content="Refresh Status"/>
            <Button Name="StartBtn" Grid.Row="0" Grid.Column="2" Margin="4" Content="Start Session" FontWeight="Bold"/>
            <Button Name="StopBtn" Grid.Row="0" Grid.Column="3" Margin="4" Content="Stop + Build Upload" FontWeight="Bold"/>
            <Button Name="StatusBtn" Grid.Row="0" Grid.Column="4" Margin="4" Content="Status"/>
            <Button Name="SettingsBtn" Grid.Row="0" Grid.Column="5" Margin="4" Content="Settings"/>

            <Button Name="ReportBtn" Grid.Row="1" Grid.Column="0" Margin="4" Content="Rebuild Report"/>
            <Button Name="OpenSessionBtn" Grid.Row="1" Grid.Column="1" Margin="4" Content="Open Latest Session"/>
            <Button Name="OpenUploadBtn" Grid.Row="1" Grid.Column="2" Margin="4" Content="Open Upload Folder"/>
            <Button Name="CopyZipBtn" Grid.Row="1" Grid.Column="3" Margin="4" Content="Copy Upload Zip Path"/>
            <Button Name="ValidateBtn" Grid.Row="1" Grid.Column="4" Margin="4" Content="Validate Setup"/>
            <Button Name="ClearBtn" Grid.Row="1" Grid.Column="5" Margin="4" Content="Clear Log"/>
          </Grid>

          <TextBox Name="LogBox" Grid.Row="1" Background="#020617" Foreground="#E5E7EB" FontFamily="Consolas"
                   FontSize="13" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                   HorizontalScrollBarVisibility="Auto" AcceptsReturn="True"/>
        </Grid>
      </TabItem>

      <TabItem Header="NVIDIA / Display">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <Grid Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="260"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.ColumnSpan="2" Text="Read-only NVIDIA / Display audit" Foreground="#F9FAFB" FontSize="18" FontWeight="Bold" Margin="0,0,0,12"/>
            <TextBlock Grid.Row="1" Grid.Column="0" Text="NVIDIA GPU detected" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaGpuValue" Grid.Row="1" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="2" Grid.Column="0" Text="NVIDIA driver version" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaDriverValue" Grid.Row="2" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="3" Grid.Column="0" Text="nvidia-smi" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaSmiValue" Grid.Row="3" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="4" Grid.Column="0" Text="NVIDIA Profile Inspector" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaProfileInspectorValue" Grid.Row="4" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="5" Grid.Column="0" Text="HAGS / MPO" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaHagsMpoValue" Grid.Row="5" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="6" Grid.Column="0" Text="Active display" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaDisplayValue" Grid.Row="6" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="7" Grid.Column="0" Text="RTSS / MSI Afterburner" Foreground="#CBD5E1" Margin="0,5,12,5"/>
            <TextBlock Name="NvidiaOverlayValue" Grid.Row="7" Grid.Column="1" Foreground="#F9FAFB" Text="Not checked" TextWrapping="Wrap" Margin="0,5,0,5"/>
            <TextBlock Grid.Row="8" Grid.ColumnSpan="2" Text="This PR does not write NVIDIA profiles, import profile files, run silent profile imports, or change global NVIDIA driver settings." Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,14,0,0"/>
          </Grid>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Audio / Sonar"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Read-only controls will land in a later PR."/></TabItem>
      <TabItem Header="Controller / HID"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Read-only controls will land in a later PR."/></TabItem>
      <TabItem Header="Windows Gaming Health"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Read-only controls will land in a later PR."/></TabItem>
      <TabItem Header="Apps / Tools"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Read-only controls will land in a later PR."/></TabItem>
      <TabItem Header="Reports"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Read-only controls will land in a later PR."/></TabItem>
      <TabItem Header="Advanced / Revert"><TextBlock Foreground="#94A3B8" Margin="10" Text="Foundation page. Reversible actions will require explicit audit and confirmation in later PRs."/></TabItem>
    </TabControl>
  </DockPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$LogBox = $window.FindName("LogBox")
$Footer = $window.FindName("Footer")
$DashboardGrid = $window.FindName("DashboardGrid")
$DashboardCards = @{}
$script:HaloSightCommandRunning = $false
$script:HaloSightRunningProcess = $null
$NvidiaGpuValue = $window.FindName("NvidiaGpuValue")
$NvidiaDriverValue = $window.FindName("NvidiaDriverValue")
$NvidiaSmiValue = $window.FindName("NvidiaSmiValue")
$NvidiaProfileInspectorValue = $window.FindName("NvidiaProfileInspectorValue")
$NvidiaHagsMpoValue = $window.FindName("NvidiaHagsMpoValue")
$NvidiaDisplayValue = $window.FindName("NvidiaDisplayValue")
$NvidiaOverlayValue = $window.FindName("NvidiaOverlayValue")

function Get-HaloSightBadgeBrush($state){
    switch($state){
        'GOOD' { return '#166534' }
        'WARN' { return '#A16207' }
        'BAD' { return '#991B1B' }
        default { return '#475569' }
    }
}

function New-HaloSightDashboardCard($title){
    $border = New-Object Windows.Controls.Border
    $border.Margin = '4'
    $border.Padding = '10'
    $border.Background = '#0F172A'
    $border.BorderBrush = '#334155'
    $border.BorderThickness = '1'
    $stack = New-Object Windows.Controls.StackPanel
    $titleBlock = New-Object Windows.Controls.TextBlock
    $titleBlock.Text = $title
    $titleBlock.Foreground = '#CBD5E1'
    $titleBlock.FontWeight = 'SemiBold'
    $badge = New-Object Windows.Controls.TextBlock
    $badge.Text = 'UNKNOWN'
    $badge.Foreground = '#FFFFFF'
    $badge.Background = (Get-HaloSightBadgeBrush 'UNKNOWN')
    $badge.Padding = '6,2,6,2'
    $badge.Margin = '0,6,0,4'
    $badge.HorizontalAlignment = 'Left'
    $detail = New-Object Windows.Controls.TextBlock
    $detail.Text = 'Not checked'
    $detail.Foreground = '#94A3B8'
    $detail.TextWrapping = 'Wrap'
    $stack.Children.Add($titleBlock) | Out-Null
    $stack.Children.Add($badge) | Out-Null
    $stack.Children.Add($detail) | Out-Null
    $border.Child = $stack
    $DashboardCards[$title] = [pscustomobject]@{ Badge=$badge; Detail=$detail }
    $DashboardGrid.Children.Add($border) | Out-Null
}

function Set-HaloSightDashboardCard($title, $state, $detail){
    if(!$DashboardCards.ContainsKey($title)){ return }
    $DashboardCards[$title].Badge.Text = $state
    $DashboardCards[$title].Badge.Background = Get-HaloSightBadgeBrush $state
    $DashboardCards[$title].Detail.Text = $detail
}

function Update-HaloSightButtonStates($dashboardState){
    $StartBtn = $window.FindName("StartBtn")
    $StopBtn = $window.FindName("StopBtn")
    $StatusBtn = $window.FindName("StatusBtn")
    $ReportBtn = $window.FindName("ReportBtn")
    $SettingsBtn = $window.FindName("SettingsBtn")
    $CopyZipBtn = $window.FindName("CopyZipBtn")
    $OpenUploadBtn = $window.FindName("OpenUploadBtn")
    $OpenSessionBtn = $window.FindName("OpenSessionBtn")
    $active = [bool]$dashboardState.ActiveSession
    $hasZip = -not [string]::IsNullOrWhiteSpace($dashboardState.LatestUploadZip)
    $hasSession = -not [string]::IsNullOrWhiteSpace($dashboardState.LatestSession)
    if($script:HaloSightCommandRunning){
        $StartBtn.IsEnabled = $false
        $StopBtn.IsEnabled = $false
        $StatusBtn.IsEnabled = $false
        $ReportBtn.IsEnabled = $false
        $SettingsBtn.IsEnabled = $false
    }else{
        $StartBtn.IsEnabled = -not $active
        $StopBtn.IsEnabled = $active
        $StatusBtn.IsEnabled = $true
        $ReportBtn.IsEnabled = $true
        $SettingsBtn.IsEnabled = $true
    }
    $CopyZipBtn.IsEnabled = $hasZip
    $OpenUploadBtn.IsEnabled = $hasZip
    $OpenSessionBtn.IsEnabled = $hasSession
}

function Update-HaloSightDashboardCards {
    $dashboardState = Get-HaloSightDashboardState
    foreach($card in $dashboardState.Cards){
        Set-HaloSightDashboardCard $card.Title $card.State $card.Detail
    }
    Update-GPTOPTNvidiaDisplayPage
    Update-HaloSightButtonStates $dashboardState
    return $dashboardState
}

function Update-GPTOPTNvidiaDisplayPage {
    $state = Get-GPTOPTNvidiaDisplayState
    $NvidiaGpuValue.Text = if($state.NvidiaGpuDetected){ $state.NvidiaGpuName }else{ 'No NVIDIA GPU detected' }
    $NvidiaDriverValue.Text = $state.DriverVersion
    $NvidiaSmiValue.Text = if($state.NvidiaSmiAvailable){ "Available: $($state.NvidiaSmiPath)" }else{ 'Not found on PATH' }
    $NvidiaProfileInspectorValue.Text = if($state.NvidiaProfileInspectorAvailable){ "Available: $($state.NvidiaProfileInspectorPath)" }else{ "Not found: $($state.NvidiaProfileInspectorPath)" }
    $NvidiaHagsMpoValue.Text = "HAGS=$($state.HagsValue) MPO=$($state.MpoValue)"
    $NvidiaDisplayValue.Text = $state.ActiveDisplay
    $NvidiaOverlayValue.Text = "RTSS=$($state.RtssDetail) MSI Afterburner=$($state.AfterburnerDetail)"
}

function Append-Log($text){
    $stamp = Get-Date -Format "HH:mm:ss"
    $LogBox.AppendText("[$stamp] $text`r`n")
    $LogBox.ScrollToEnd()
}

function Invoke-HaloSightAsync($mode){
    if($script:HaloSightCommandRunning){
        Append-Log "Already running: $($script:HaloSightRunningMode)"
        return
    }

    Reload-HSConfig
    $script:HaloSightCommandRunning = $true
    $script:HaloSightRunningMode = $mode
    $Footer.Text = "Running: $mode..."
    Update-HaloSightDashboardCards | Out-Null
    Append-Log "Running: $mode..."

    $outputLines = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    $errorLines = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))

    try{
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" -Mode $mode"
        $psi.WorkingDirectory = $Root
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.EnableRaisingEvents = $true
        $p.add_OutputDataReceived({
            param($sender,$args)
            if($null -ne $args.Data){ [void]$outputLines.Add($args.Data) }
        })
        $p.add_ErrorDataReceived({
            param($sender,$args)
            if($null -ne $args.Data){ [void]$errorLines.Add($args.Data) }
        })
        $p.add_Exited({
            param($sender,$args)
            $completedMode = $mode
            $exitCode = $sender.ExitCode
            $stdout = ($outputLines.ToArray() -join "`r`n").Trim()
            $stderr = ($errorLines.ToArray() -join "`r`n").Trim()
            $window.Dispatcher.BeginInvoke([Action]{
                try{
                    if($stdout){ Append-Log $stdout }
                    if($stderr){ Append-Log $stderr }
                    Reload-HSConfig
                    if($completedMode -in @('stop','report')){
                        Handle-UploadActions
                    }else{
                        Update-HaloSightDashboardCards | Out-Null
                    }
                    if($exitCode -eq 0){
                        $Footer.Text = "Completed: $completedMode."
                    }else{
                        $Footer.Text = "Error running $completedMode. Exit code: $exitCode"
                    }
                }finally{
                    $script:HaloSightCommandRunning = $false
                    $script:HaloSightRunningProcess = $null
                    Update-HaloSightDashboardCards | Out-Null
                    $sender.Dispose()
                }
            }) | Out-Null
        })

        [void]$p.Start()
        $script:HaloSightRunningProcess = $p
        $p.BeginOutputReadLine()
        $p.BeginErrorReadLine()
    }catch{
        $script:HaloSightCommandRunning = $false
        $script:HaloSightRunningProcess = $null
        Append-Log $_.Exception.Message
        $Footer.Text = "Error running $mode."
        Update-HaloSightDashboardCards | Out-Null
    }
}

function Handle-UploadActions {
    $z = Get-LatestUploadZip
    if($z){
        $Footer.Text = "Upload package: $z"
        if($Config.UI.AutoCopyUploadZipPath){
            [System.Windows.Forms.Clipboard]::SetText($z)
            Append-Log "Copied upload zip path: $z"
        }
        if($Config.UI.AutoOpenUploadFolder){
            Start-Process explorer.exe $SessionRoot
            Append-Log "Opened upload folder: $SessionRoot"
        }
    }
    Update-HaloSightDashboardCards | Out-Null
}

@('Active Session','Halo','RTSS','MSI Afterburner','CapFrameX','OBS','Timer Resolution','Gaming Services','Audio/Sonar','Problem Devices','Pending Reboot/Rename','Latest Upload Zip','NVIDIA GPU','NVIDIA Driver','NVIDIA Profile Inspector') |
    ForEach-Object { New-HaloSightDashboardCard $_ }

$window.FindName("StartBtn").Add_Click({
    Invoke-HaloSightAsync "start"
})

$window.FindName("StopBtn").Add_Click({
    Invoke-HaloSightAsync "stop"
})

$window.FindName("ReadyBtn").Add_Click({
    Update-HaloSightDashboardCards | Out-Null
    $Footer.Text = "Read-only readiness check refreshed."
})

$window.FindName("RefreshBtn").Add_Click({
    Update-HaloSightDashboardCards | Out-Null
    $Footer.Text = "Status refreshed."
})

$window.FindName("StatusBtn").Add_Click({
    Invoke-HaloSightAsync "status"
})

$window.FindName("ReportBtn").Add_Click({
    Invoke-HaloSightAsync "report"
})

$window.FindName("SettingsBtn").Add_Click({
    Show-SettingsWindow
})

$window.FindName("ValidateBtn").Add_Click({
    $result = Test-HaloSightConfig
    if($result.IsValid){ Append-Log "Settings valid." }else{ Append-Log ("Settings errors: " + ($result.Errors -join '; ')) }
    if($result.Warnings.Count -gt 0){ Append-Log ("Settings warnings: " + ($result.Warnings -join '; ')) }
    Update-HaloSightDashboardCards | Out-Null
})

$window.FindName("OpenSessionBtn").Add_Click({
    $p = Get-LatestSessionPath
    if($p){ Start-Process explorer.exe $p; Append-Log "Opened: $p" }
    else{ Append-Log "No session folder found." }
})

$window.FindName("OpenUploadBtn").Add_Click({
    New-Item -ItemType Directory -Path $SessionRoot -Force | Out-Null
    Start-Process explorer.exe $SessionRoot
    Append-Log "Opened upload folder: $SessionRoot"
})

$window.FindName("CopyZipBtn").Add_Click({
    $z = Get-LatestUploadZip
    if($z){
        [System.Windows.Forms.Clipboard]::SetText($z)
        Append-Log "Copied upload zip path: $z"
        $Footer.Text = "Copied: $z"
    } else {
        Append-Log "No _UPLOAD.zip found."
    }
})

$window.FindName("ClearBtn").Add_Click({
    $LogBox.Clear()
})

Append-Log "HaloSight GUI ready."
Append-Log "Use Settings before capture if you want to change evidence folders, limits, or upload behavior."
Update-HaloSightDashboardCards | Out-Null
if($OpenSettings){
    $window.Add_ContentRendered({ Show-SettingsWindow })
}
$window.ShowDialog() | Out-Null
