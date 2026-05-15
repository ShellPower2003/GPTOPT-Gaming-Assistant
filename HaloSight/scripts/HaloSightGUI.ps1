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

function Run-HS($mode){
    Reload-HSConfig
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" -Mode $mode"
    $psi.WorkingDirectory = $Root
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    Reload-HSConfig
    return ($out + "`r`n" + $err).Trim()
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

function ConvertTo-Multiline($items){ return (@($items) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`r`n" }
function ConvertFrom-Multiline($text){ return @($text -split "(`r`n|`n|;)" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

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
        }catch{ [Windows.MessageBox]::Show($_.Exception.Message, 'Settings Error') | Out-Null }
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
        Title="GPTOPT HaloSight GUI v0.4" Height="660" Width="1040"
        WindowStartupLocation="CenterScreen" Background="#111827">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,10">
      <TextBlock Text="GPTOPT HaloSight" Foreground="#F9FAFB" FontSize="26" FontWeight="Bold"/>
      <TextBlock Text="External Halo Infinite session capture. No injection. No browser closing. No Halo priority changes." Foreground="#CBD5E1" FontSize="13"/>
    </StackPanel>

    <Grid Grid.Row="1" Margin="0,0,0,10">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
        <RowDefinition Height="44"/>
        <RowDefinition Height="44"/>
      </Grid.RowDefinitions>

      <Button Name="StartBtn" Grid.Row="0" Grid.Column="0" Margin="4" Content="Start Session" FontWeight="Bold"/>
      <Button Name="StopBtn" Grid.Row="0" Grid.Column="1" Margin="4" Content="Stop + Build Upload" FontWeight="Bold"/>
      <Button Name="StatusBtn" Grid.Row="0" Grid.Column="2" Margin="4" Content="Status"/>
      <Button Name="ReportBtn" Grid.Row="0" Grid.Column="3" Margin="4" Content="Rebuild Report"/>
      <Button Name="SettingsBtn" Grid.Row="0" Grid.Column="4" Margin="4" Content="Settings"/>

      <Button Name="OpenSessionBtn" Grid.Row="1" Grid.Column="0" Margin="4" Content="Open Latest Session"/>
      <Button Name="OpenUploadBtn" Grid.Row="1" Grid.Column="1" Margin="4" Content="Open Upload Folder"/>
      <Button Name="CopyZipBtn" Grid.Row="1" Grid.Column="2" Margin="4" Content="Copy Upload Zip Path"/>
      <Button Name="ValidateBtn" Grid.Row="1" Grid.Column="3" Margin="4" Content="Validate Setup"/>
      <Button Name="ClearBtn" Grid.Row="1" Grid.Column="4" Margin="4" Content="Clear Log"/>
    </Grid>

    <TextBox Name="LogBox" Grid.Row="2" Background="#020617" Foreground="#E5E7EB" FontFamily="Consolas"
             FontSize="13" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
             HorizontalScrollBarVisibility="Auto" AcceptsReturn="True"/>

    <TextBlock Name="Footer" Grid.Row="3" Foreground="#94A3B8" Margin="0,8,0,0"
               Text="Flow: Start Session -> play/capture match -> Stop + Build Upload -> send _UPLOAD.zip"/>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$LogBox = $window.FindName("LogBox")
$Footer = $window.FindName("Footer")

function Append-Log($text){
    $stamp = Get-Date -Format "HH:mm:ss"
    $LogBox.AppendText("[$stamp] $text`r`n")
    $LogBox.ScrollToEnd()
}

function Handle-UploadActions {
    $z = Get-LatestUploadZip
    if($z){
        $Footer.Text = "Upload package: $z"
        if($Config.UI.AutoCopyUploadZipPath){ [System.Windows.Forms.Clipboard]::SetText($z); Append-Log "Copied upload zip path: $z" }
        if($Config.UI.AutoOpenUploadFolder){ Start-Process explorer.exe $SessionRoot; Append-Log "Opened upload folder: $SessionRoot" }
    }
}

$window.FindName("StartBtn").Add_Click({ Append-Log "Starting session..."; Append-Log (Run-HS "start"); $Footer.Text = "Active session started." })
$window.FindName("StopBtn").Add_Click({ Append-Log "Stopping session and building upload package..."; Append-Log (Run-HS "stop"); Handle-UploadActions })
$window.FindName("StatusBtn").Add_Click({ Append-Log "Checking status..."; Append-Log (Run-HS "status") })
$window.FindName("ReportBtn").Add_Click({ Append-Log "Rebuilding latest report/package..."; Append-Log (Run-HS "report"); Handle-UploadActions })
$window.FindName("SettingsBtn").Add_Click({ Show-SettingsWindow })
$window.FindName("ValidateBtn").Add_Click({
    $result = Test-HaloSightConfig
    if($result.IsValid){ Append-Log "Settings valid." }else{ Append-Log ("Settings errors: " + ($result.Errors -join '; ')) }
    if($result.Warnings.Count -gt 0){ Append-Log ("Settings warnings: " + ($result.Warnings -join '; ')) }
})
$window.FindName("OpenSessionBtn").Add_Click({ $p = Get-LatestSessionPath; if($p){ Start-Process explorer.exe $p; Append-Log "Opened: $p" }else{ Append-Log "No session folder found." } })
$window.FindName("OpenUploadBtn").Add_Click({ New-Item -ItemType Directory -Path $SessionRoot -Force | Out-Null; Start-Process explorer.exe $SessionRoot; Append-Log "Opened upload folder: $SessionRoot" })
$window.FindName("CopyZipBtn").Add_Click({ $z = Get-LatestUploadZip; if($z){ [System.Windows.Forms.Clipboard]::SetText($z); Append-Log "Copied upload zip path: $z"; $Footer.Text = "Copied: $z" }else{ Append-Log "No _UPLOAD.zip found." } })
$window.FindName("ClearBtn").Add_Click({ $LogBox.Clear() })

Append-Log "HaloSight GUI ready."
Append-Log "Use Settings before capture if you want to change evidence folders, limits, or upload behavior."
if($OpenSettings){ $window.Add_ContentRendered({ Show-SettingsWindow }) }
$window.ShowDialog() | Out-Null
