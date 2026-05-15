Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$Root = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $PSScriptRoot "HaloSight.ps1"
$ConfigPath = Join-Path $Root "config\halosight.config.json"
$Config = if(Test-Path $ConfigPath){ Get-Content $ConfigPath -Raw | ConvertFrom-Json }else{ $null }
$SessionRoot = if($Config -and $Config.SessionRoot){
    [Environment]::ExpandEnvironmentVariables($Config.SessionRoot)
}else{
    Join-Path $env:USERPROFILE "Documents\GPTOPT\HaloSight\sessions"
}

function Run-HS($mode){
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
    return ($out + "`r`n" + $err).Trim()
}

function Get-LatestSessionPath {
    if(!(Test-Path $SessionRoot)){ return $null }
    $d = Get-ChildItem $SessionRoot -Directory -Filter "session_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($d){ return $d.FullName }
    return $null
}

function Get-LatestUploadZip {
    if(!(Test-Path $SessionRoot)){ return $null }
    $z = Get-ChildItem $SessionRoot -File -Filter "*_UPLOAD.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($z){ return $z.FullName }
    return $null
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GPTOPT HaloSight GUI v0.4" Height="620" Width="940"
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
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
        <RowDefinition Height="44"/>
        <RowDefinition Height="44"/>
      </Grid.RowDefinitions>

      <Button Name="StartBtn" Grid.Row="0" Grid.Column="0" Margin="4" Content="Start Session" FontWeight="Bold"/>
      <Button Name="StopBtn" Grid.Row="0" Grid.Column="1" Margin="4" Content="Stop + Build Upload" FontWeight="Bold"/>
      <Button Name="StatusBtn" Grid.Row="0" Grid.Column="2" Margin="4" Content="Status"/>
      <Button Name="ReportBtn" Grid.Row="0" Grid.Column="3" Margin="4" Content="Rebuild Report"/>

      <Button Name="OpenSessionBtn" Grid.Row="1" Grid.Column="0" Margin="4" Content="Open Latest Session"/>
      <Button Name="OpenUploadBtn" Grid.Row="1" Grid.Column="1" Margin="4" Content="Open Upload Folder"/>
      <Button Name="CopyZipBtn" Grid.Row="1" Grid.Column="2" Margin="4" Content="Copy Upload Zip Path"/>
      <Button Name="ClearBtn" Grid.Row="1" Grid.Column="3" Margin="4" Content="Clear Log"/>
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

$window.FindName("StartBtn").Add_Click({
    Append-Log "Starting session..."
    $r = Run-HS "start"
    Append-Log $r
    $Footer.Text = "Active session started."
})

$window.FindName("StopBtn").Add_Click({
    Append-Log "Stopping session and building upload package..."
    $r = Run-HS "stop"
    Append-Log $r
    $z = Get-LatestUploadZip
    if($z){ $Footer.Text = "Upload package: $z" }
})

$window.FindName("StatusBtn").Add_Click({
    Append-Log "Checking status..."
    Append-Log (Run-HS "status")
})

$window.FindName("ReportBtn").Add_Click({
    Append-Log "Rebuilding latest report/package..."
    Append-Log (Run-HS "report")
    $z = Get-LatestUploadZip
    if($z){ $Footer.Text = "Upload package: $z" }
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
Append-Log "Use Start Session before match. Use Stop + Build Upload after match."
$window.ShowDialog() | Out-Null
