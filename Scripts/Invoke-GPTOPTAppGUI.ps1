param()

Add-Type -AssemblyName PresentationFramework

$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $Root 'Config'
$ReportsDir = Join-Path $Root 'Reports'
$SettingsPath = Join-Path $ConfigDir 'GPTOPTAppSettings.json'
New-Item -ItemType Directory -Force -Path $ConfigDir,$ReportsDir | Out-Null

function Load-AppSettings {
    if (Test-Path -LiteralPath $SettingsPath) {
        try { return Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json } catch {}
    }
    [pscustomobject]@{ DefaultContext='NormalGaming'; ShowInfoRecommendations=$false; OpenReportFolderAfterBuild=$true }
}

function Save-AppSettings($s) {
    $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
}

$Settings = Load-AppSettings

function Add-Log($m) {
    $time = Get-Date -Format 'HH:mm:ss'
    $Log.AppendText("[$time] $m`r`n")
    $Log.ScrollToEnd()
}

function Run-Mode($mode, $context) {
    $runner = Join-Path $Root 'Run-GPTOPT.ps1'
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-Mode',$mode)
    if ($context) { $args += @('-Context',$context) }
    & powershell.exe @args 2>&1 | Out-String
}

function Launch-Mode($mode, $context) {
    $runner = Join-Path $Root 'Run-GPTOPT.ps1'
    $argText = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$runner`" -Mode $mode"
    if ($context) { $argText += " -Context $context" }
    Start-Process powershell.exe -ArgumentList $argText -WorkingDirectory $Root | Out-Null
}

function Get-HaloSettingsPath { Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings\SpecControlSettings.json' }
function Get-HaloSettingsDir { Split-Path -Parent (Get-HaloSettingsPath) }

function Get-FlatHaloJsonValues([string]$Path) {
    $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $map = [ordered]@{}
    foreach ($p in $json.PSObject.Properties) {
        $x = $p.Value
        $val = $null
        if ($null -eq $x) { $val = $null }
        elseif ($x -is [string] -or $x -is [int] -or $x -is [double] -or $x -is [bool]) { $val = $x }
        else {
            foreach ($leaf in 'value','Value','current','Current','data','Data','setting','Setting') {
                if ($x.PSObject.Properties.Name -contains $leaf) { $val = $x.$leaf; break }
            }
            if ($null -eq $val) { $val = ($x | ConvertTo-Json -Compress -Depth 8) }
        }
        $map[$p.Name] = "$val"
    }
    $map
}

function Show-HaloCurrentSettings {
    try {
        $cfg = Get-HaloSettingsPath
        if (!(Test-Path -LiteralPath $cfg)) { $HaloConfigBox.Text = "Halo config not found: $cfg"; return }
        $map = Get-FlatHaloJsonValues $cfg
        $keys = @(
            'spec_control_minimum_framerate','spec_control_target_framerate','spec_control_resolution_scale','spec_control_ui_resolution_scale',
            'spec_control_windowed_display_resolution_x','spec_control_windowed_display_resolution_y','spec_control_vsync','cap_frame_rate_on_loss_of_focus',
            'spec_control_animation_quality','spec_control_simulation_quality','spec_control_texture_quality','spec_control_shadow_quality',
            'spec_control_effects_quality','spec_control_geometry_quality','spec_control_reflections_quality','spec_control_volumetric_fog_quality','spec_control_terrain_quality'
        )
        $rows = foreach ($k in $keys) { if ($map.Contains($k)) { [pscustomobject]@{ Setting=$k; Current=$map[$k] } } }
        $HaloConfigBox.Text = ($rows | Format-Table -AutoSize | Out-String)
        Add-Log 'Halo current config loaded. No edits made.'
    } catch { Add-Log "Halo config read failed: $($_.Exception.Message)" }
}

function Show-HaloConfigDrift {
    try {
        $cfg = Get-HaloSettingsPath
        $dir = Get-HaloSettingsDir
        if (!(Test-Path -LiteralPath $cfg)) { $HaloConfigBox.Text = "Halo config not found: $cfg"; return }
        $backups = @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'SpecControlSettings\.json' -and $_.FullName -ne $cfg } | Sort-Object LastWriteTime -Descending)
        if ($backups.Count -eq 0) { $HaloConfigBox.Text = "No SpecControlSettings backups found in $dir"; return }
        $curMap = Get-FlatHaloJsonValues $cfg
        $b = $backups[0]
        $oldMap = Get-FlatHaloJsonValues $b.FullName
        $keys = @($curMap.Keys + $oldMap.Keys | Sort-Object -Unique)
        $diff = foreach ($k in $keys) {
            $old = if ($oldMap.Contains($k)) { $oldMap[$k] } else { '<missing>' }
            $new = if ($curMap.Contains($k)) { $curMap[$k] } else { '<missing>' }
            if ("$old" -ne "$new" -and $k -match 'framerate|resolution|scale|vsync|quality|shadow|texture|effects|geometry|reflection|volumetric|animation|simulation|terrain|display|monitor|window') {
                [pscustomobject]@{ Setting=$k; Backup=$old; Current=$new }
            }
        }
        $header = "Compared current config to latest backup:`r`n$($b.FullName)`r`nBackup time: $($b.LastWriteTime)`r`n`r`n"
        if ($diff) { $HaloConfigBox.Text = $header + ($diff | Format-Table -AutoSize | Out-String) }
        else { $HaloConfigBox.Text = $header + 'No important gameplay/render drift found.' }
        Add-Log 'Halo config drift check complete. No edits made.'
    } catch { Add-Log "Halo drift check failed: $($_.Exception.Message)" }
}

function Show-HaloBackups {
    try {
        $dir = Get-HaloSettingsDir
        $backups = @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'SpecControlSettings\.json' } | Sort-Object LastWriteTime -Descending | Select-Object -First 25 Name,LastWriteTime,Length,FullName)
        $HaloConfigBox.Text = if ($backups) { $backups | Format-Table -AutoSize | Out-String } else { "No Halo settings files found in $dir" }
        Add-Log 'Halo settings backups listed.'
    } catch { Add-Log "Halo backup list failed: $($_.Exception.Message)" }
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="GPTOPT Gaming Assistant" Height="780" Width="1120" WindowStartupLocation="CenterScreen" Background="#151515">
  <Grid Margin="10">
    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="160"/></Grid.RowDefinitions>
    <TabControl Name="Tabs" Grid.Row="0" Background="#202020" Foreground="White">
      <TabItem Header="Home"><StackPanel Margin="16"><TextBlock Text="GPTOPT Gaming Assistant" FontSize="28" FontWeight="Bold" Foreground="White"/><TextBlock Text="Preview-only control app. No live system changes." Foreground="#AAAAAA" Margin="0,4,0,16"/><WrapPanel><Button Name="AuditBtn" Content="Run Audit" Width="180" Height="44" Margin="0,0,10,10"/><Button Name="ReportBtn" Content="Build Report" Width="180" Height="44" Margin="0,0,10,10"/><Button Name="RecBtn" Content="Recommendations" Width="180" Height="44" Margin="0,0,10,10"/><Button Name="QueueBtn" Content="Preview Queue" Width="180" Height="44" Margin="0,0,10,10"/><Button Name="SafetyBtn" Content="Safety Scan" Width="180" Height="44" Margin="0,0,10,10"/></WrapPanel><TextBox Name="HomeBox" Height="430" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#101010" Foreground="#EDEDED" FontFamily="Consolas"/></StackPanel></TabItem>
      <TabItem Header="Recommendations"><StackPanel Margin="16"><StackPanel Orientation="Horizontal"><TextBlock Text="Context:" Foreground="White" VerticalAlignment="Center" Margin="0,0,8,0"/><ComboBox Name="ContextBox" Width="230"><ComboBoxItem Content="NormalGaming"/><ComboBoxItem Content="BenchmarkCapture"/><ComboBoxItem Content="HaloTroubleshooting"/><ComboBoxItem Content="FullOptimizationPreview"/></ComboBox><CheckBox Name="ShowInfo" Content="Show Info" Foreground="White" Margin="16,0,0,0"/><Button Name="RefreshRecBtn" Content="Refresh" Width="120" Margin="16,0,0,0"/></StackPanel><TextBox Name="RecBox" Height="520" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#101010" Foreground="#EDEDED" FontFamily="Consolas" Margin="0,12,0,0"/></StackPanel></TabItem>
      <TabItem Header="Preview Queue"><StackPanel Margin="16"><WrapPanel><Button Name="BuildQueueBtn" Content="Build Queue" Width="150" Height="40" Margin="0,0,10,10"/><Button Name="BackupBtn" Content="Backup Plan Preview" Width="190" Height="40" Margin="0,0,10,10"/><Button Name="ExportReportBtn" Content="Export Report" Width="150" Height="40" Margin="0,0,10,10"/></WrapPanel><TextBox Name="QueueBox" Height="520" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#101010" Foreground="#EDEDED" FontFamily="Consolas"/></StackPanel></TabItem>
      <TabItem Header="Halo Config"><StackPanel Margin="16"><TextBlock Text="Halo config drift tools" FontSize="22" FontWeight="Bold" Foreground="White"/><TextBlock Text="Read-only. Compares current Halo SpecControlSettings.json to your own backups. Does not edit Halo settings." Foreground="#AAAAAA" Margin="0,4,0,16"/><WrapPanel><Button Name="HaloCurrentBtn" Content="Current Key Settings" Width="180" Height="40" Margin="0,0,10,10"/><Button Name="HaloDriftBtn" Content="Compare Latest Backup" Width="190" Height="40" Margin="0,0,10,10"/><Button Name="HaloBackupsBtn" Content="List Backups" Width="150" Height="40" Margin="0,0,10,10"/><Button Name="OpenHaloSettingsBtn" Content="Open Halo Settings Folder" Width="210" Height="40" Margin="0,0,10,10"/></WrapPanel><TextBox Name="HaloConfigBox" Height="500" IsReadOnly="True" TextWrapping="NoWrap" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#101010" Foreground="#EDEDED" FontFamily="Consolas"/></StackPanel></TabItem>
      <TabItem Header="HaloSight"><StackPanel Margin="16"><TextBlock Text="HaloSight capture tools stay in the old GUI." Foreground="White" FontSize="18" FontWeight="Bold"/><WrapPanel Margin="0,16,0,0"><Button Name="OldHaloBtn" Content="Launch Old HaloSight GUI" Width="220" Height="42" Margin="0,0,10,10"/><Button Name="OpenReportsBtn" Content="Open Reports" Width="160" Height="42" Margin="0,0,10,10"/><Button Name="OpenAppBtn" Content="Open App Folder" Width="160" Height="42" Margin="0,0,10,10"/></WrapPanel></StackPanel></TabItem>
      <TabItem Header="Settings"><StackPanel Margin="16"><TextBlock Text="GPTOPT App Settings" FontSize="22" FontWeight="Bold" Foreground="White"/><TextBlock Text="Repo/app settings only. No Windows or Halo game settings are changed." Foreground="#AAAAAA" Margin="0,4,0,16"/><TextBlock Text="Default Context" Foreground="White"/><ComboBox Name="DefaultContext" Width="260" HorizontalAlignment="Left"><ComboBoxItem Content="NormalGaming"/><ComboBoxItem Content="BenchmarkCapture"/><ComboBoxItem Content="HaloTroubleshooting"/><ComboBoxItem Content="FullOptimizationPreview"/></ComboBox><CheckBox Name="DefaultShowInfo" Content="Show Info Recommendations by Default" Foreground="White" Margin="0,14,0,0"/><CheckBox Name="OpenReportFolder" Content="Open Report Folder After Build" Foreground="White" Margin="0,8,0,0"/><Button Name="SaveBtn" Content="Save Settings" Width="160" Height="40" Margin="0,18,0,0" HorizontalAlignment="Left"/></StackPanel></TabItem>
      <TabItem Header="Safety"><StackPanel Margin="16"><TextBlock Text="Safety" FontSize="22" FontWeight="Bold" Foreground="White"/><TextBlock Text="Apply and rollback are disabled. This app is audit/recommend/preview/report only." Foreground="#AAAAAA" Margin="0,4,0,16"/><Button Name="RunSafetyBtn" Content="Run Safety Scanner" Width="190" Height="42"/><TextBox Name="SafetyBox" Height="500" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#101010" Foreground="#EDEDED" FontFamily="Consolas" Margin="0,12,0,0"/></StackPanel></TabItem>
    </TabControl>
    <DockPanel Grid.Row="1" Margin="0,10,0,0"><TextBlock DockPanel.Dock="Top" Text="Log" Foreground="White" FontWeight="Bold"/><TextBox Name="Log" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080808" Foreground="#EDEDED" FontFamily="Consolas"/></DockPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$Log = $Window.FindName('Log')
$HomeBox = $Window.FindName('HomeBox')
$RecBox = $Window.FindName('RecBox')
$QueueBox = $Window.FindName('QueueBox')
$SafetyBox = $Window.FindName('SafetyBox')
$HaloConfigBox = $Window.FindName('HaloConfigBox')
$ContextBox = $Window.FindName('ContextBox')
$ShowInfo = $Window.FindName('ShowInfo')

$contexts = @('NormalGaming','BenchmarkCapture','HaloTroubleshooting','FullOptimizationPreview')
$idx = [array]::IndexOf($contexts, [string]$Settings.DefaultContext); if ($idx -lt 0) { $idx = 0 }
$ContextBox.SelectedIndex = $idx
$Window.FindName('DefaultContext').SelectedIndex = $idx
$ShowInfo.IsChecked = [bool]$Settings.ShowInfoRecommendations
$Window.FindName('DefaultShowInfo').IsChecked = [bool]$Settings.ShowInfoRecommendations
$Window.FindName('OpenReportFolder').IsChecked = [bool]$Settings.OpenReportFolderAfterBuild

function CurrentContext { if ($ContextBox.SelectedItem) { $ContextBox.SelectedItem.Content.ToString() } else { 'NormalGaming' } }

$Window.FindName('AuditBtn').Add_Click({ Add-Log 'Running audit...'; $HomeBox.Text = Run-Mode 'control' ''; Add-Log 'Audit complete.' })
$Window.FindName('ReportBtn').Add_Click({ Add-Log 'Launching report...'; Launch-Mode 'report' 'HaloTroubleshooting'; if ($Settings.OpenReportFolderAfterBuild) { Start-Process explorer.exe $ReportsDir | Out-Null } })
$Window.FindName('RecBtn').Add_Click({ Add-Log 'Generating recommendations...'; $RecBox.Text = Run-Mode 'recommend' (CurrentContext); Add-Log 'Recommendations complete.' })
$Window.FindName('RefreshRecBtn').Add_Click({ Add-Log 'Generating recommendations...'; $RecBox.Text = Run-Mode 'recommend' (CurrentContext); Add-Log 'Recommendations complete.' })
$Window.FindName('QueueBtn').Add_Click({ Add-Log 'Building queue...'; $QueueBox.Text = Run-Mode 'queue' (CurrentContext); Add-Log 'Queue complete.' })
$Window.FindName('BuildQueueBtn').Add_Click({ Add-Log 'Building queue...'; $QueueBox.Text = Run-Mode 'queue' (CurrentContext); Add-Log 'Queue complete.' })
$Window.FindName('BackupBtn').Add_Click({ Add-Log 'Building backup plan...'; $QueueBox.Text = Run-Mode 'backupPlan' (CurrentContext); Add-Log 'Backup plan complete.' })
$Window.FindName('ExportReportBtn').Add_Click({ Add-Log 'Launching report...'; Launch-Mode 'report' 'HaloTroubleshooting' })
$Window.FindName('SafetyBtn').Add_Click({ Add-Log 'Running safety scan...'; $SafetyBox.Text = & powershell.exe -NoProfile -File (Join-Path $Root 'Scripts\Test-GPTOPTSafety.ps1') 2>&1 | Out-String; Add-Log 'Safety scan complete.' })
$Window.FindName('RunSafetyBtn').Add_Click({ Add-Log 'Running safety scan...'; $SafetyBox.Text = & powershell.exe -NoProfile -File (Join-Path $Root 'Scripts\Test-GPTOPTSafety.ps1') 2>&1 | Out-String; Add-Log 'Safety scan complete.' })
$Window.FindName('HaloCurrentBtn').Add_Click({ Show-HaloCurrentSettings })
$Window.FindName('HaloDriftBtn').Add_Click({ Show-HaloConfigDrift })
$Window.FindName('HaloBackupsBtn').Add_Click({ Show-HaloBackups })
$Window.FindName('OpenHaloSettingsBtn').Add_Click({ $d = Get-HaloSettingsDir; if (Test-Path $d) { Start-Process explorer.exe $d | Out-Null } })
$Window.FindName('OldHaloBtn').Add_Click({ $p = Join-Path $Root 'App\GPTOPT-HaloSight.cmd'; if (Test-Path $p) { Start-Process $p -WorkingDirectory $Root | Out-Null } })
$Window.FindName('OpenReportsBtn').Add_Click({ Start-Process explorer.exe $ReportsDir | Out-Null })
$Window.FindName('OpenAppBtn').Add_Click({ Start-Process explorer.exe (Join-Path $Root 'App') | Out-Null })
$Window.FindName('SaveBtn').Add_Click({ $Settings.DefaultContext = $Window.FindName('DefaultContext').SelectedItem.Content.ToString(); $Settings.ShowInfoRecommendations = [bool]$Window.FindName('DefaultShowInfo').IsChecked; $Settings.OpenReportFolderAfterBuild = [bool]$Window.FindName('OpenReportFolder').IsChecked; Save-AppSettings $Settings; Add-Log 'Settings saved.' })

Add-Log 'GPTOPT app GUI ready.'
Add-Log 'Preview-only. Apply/rollback disabled. No live system changes.'
$Window.ShowDialog() | Out-Null
