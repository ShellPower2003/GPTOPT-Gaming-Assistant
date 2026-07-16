#requires -Version 5.1
[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

$Root = Split-Path -Parent $PSScriptRoot
$AuditRoot = Join-Path $env:LOCALAPPDATA 'GPTOPT\Audits'
$LatestJson = Join-Path $AuditRoot 'latest\GPTOPT-SanitizedReport.json'
$Collector = Join-Path $Root 'Scripts\Invoke-GPTOPTAudit.ps1'
$ControllerAimCheck = Join-Path $Root 'Run-GPTOPTControllerAimCheck.ps1'

function Read-LatestAudit {
    if (-not (Test-Path -LiteralPath $LatestJson)) { return $null }
    try { Get-Content -Raw -LiteralPath $LatestJson | ConvertFrom-Json } catch { $null }
}

function Get-AuditHistory {
    if (-not (Test-Path -LiteralPath $AuditRoot)) { return @() }
    @(Get-ChildItem -LiteralPath $AuditRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -like 'GPTOPT-*' |
        Sort-Object Name -Descending |
        ForEach-Object {
            $report = Join-Path $_.FullName 'GPTOPT-SanitizedReport.json'
            if (Test-Path $report) {
                try {
                    $x = Get-Content -Raw $report | ConvertFrom-Json
                    [pscustomobject]@{
                        Audit = $x.audit_id
                        Collected = ([datetime]$x.collected_utc).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
                        Errors = [int]$x.health.system_error_count + [int]$x.health.application_error_count
                        ProblemDevices = $x.health.problem_device_count
                        Reboot = $x.health.pending_reboot_count
                        Folder = $_.FullName
                    }
                } catch {}
            }
        })
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="GPTOPT Gaming Assistant" Height="820" Width="1240"
        WindowStartupLocation="CenterScreen" Background="#101319" Foreground="White">
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="72"/><RowDefinition Height="*"/><RowDefinition Height="120"/></Grid.RowDefinitions>
    <Border Grid.Row="0" Background="#171C24" Padding="20,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left">
          <TextBlock Text="GPTOPT Gaming Assistant" FontSize="28" FontWeight="Bold"/>
          <TextBlock Text="Windows and Halo performance control center" Foreground="#9CA8B8"/>
        </StackPanel>
        <TextBlock Name="StatusText" DockPanel.Dock="Right" Text="Ready" VerticalAlignment="Center" FontSize="16" Foreground="#79D98C"/>
      </DockPanel>
    </Border>

    <TabControl Grid.Row="1" Margin="12" Background="#171C24" Foreground="White">
      <TabItem Header="Dashboard">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18">
            <WrapPanel>
              <Border Background="#202733" CornerRadius="8" Padding="16" Width="270" Margin="0,0,12,12"><StackPanel><TextBlock Text="Platform" Foreground="#9CA8B8"/><TextBlock Name="PlatformText" Text="No audit loaded" FontSize="16" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
              <Border Background="#202733" CornerRadius="8" Padding="16" Width="270" Margin="0,0,12,12"><StackPanel><TextBlock Text="Gaming configuration" Foreground="#9CA8B8"/><TextBlock Name="GamingText" Text="No audit loaded" FontSize="16" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
              <Border Background="#202733" CornerRadius="8" Padding="16" Width="270" Margin="0,0,12,12"><StackPanel><TextBlock Text="Devices" Foreground="#9CA8B8"/><TextBlock Name="DeviceText" Text="No audit loaded" FontSize="16" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
              <Border Background="#202733" CornerRadius="8" Padding="16" Width="270" Margin="0,0,12,12"><StackPanel><TextBlock Text="Health" Foreground="#9CA8B8"/><TextBlock Name="HealthText" Text="No audit loaded" FontSize="16" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
            </WrapPanel>
            <WrapPanel Margin="0,8,0,0">
              <Button Name="RunAuditBtn" Content="Run full audit" Width="180" Height="44" Margin="0,0,10,10"/>
              <Button Name="LocalAuditBtn" Content="Run local-only audit" Width="180" Height="44" Margin="0,0,10,10"/>
              <Button Name="RefreshBtn" Content="Refresh dashboard" Width="180" Height="44" Margin="0,0,10,10"/>
              <Button Name="OpenAuditFolderBtn" Content="Open audit storage" Width="180" Height="44" Margin="0,0,10,10"/>
              <Button Name="OpenIssueBtn" Content="Open latest GitHub report" Width="200" Height="44" Margin="0,0,10,10"/>
            </WrapPanel>
            <ProgressBar Name="AuditProgress" Height="22" Minimum="0" Maximum="100" Value="0" Margin="0,12,0,0"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Audit History">
        <Grid Margin="16">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <WrapPanel><Button Name="RefreshHistoryBtn" Content="Refresh history" Width="150" Height="38" Margin="0,0,10,10"/><Button Name="OpenSelectedBtn" Content="Open selected audit" Width="170" Height="38" Margin="0,0,10,10"/></WrapPanel>
          <DataGrid Name="HistoryGrid" Grid.Row="1" AutoGenerateColumns="True" IsReadOnly="True" Background="#101319" Foreground="White" RowBackground="#171C24" AlternatingRowBackground="#202733"/>
        </Grid>
      </TabItem>

      <TabItem Header="Halo">
        <StackPanel Margin="18">
          <TextBlock Text="Halo Infinite" FontSize="24" FontWeight="Bold"/>
          <TextBlock Text="Read-only controller and Halo diagnostics. No settings are changed." Foreground="#9CA8B8" TextWrapping="Wrap" Margin="0,6,0,16"/>
          <WrapPanel>
            <Button Name="RunControllerAimBtn" Content="Check controller aim feel" Width="220" Height="42" Margin="0,0,10,10"/>
            <Button Name="OpenControllerReportsBtn" Content="Open controller reports" Width="210" Height="42" Margin="0,0,10,10"/>
            <Button Name="OpenHaloSettingsBtn" Content="Open Halo settings folder" Width="220" Height="42" Margin="0,0,10,10"/>
          </WrapPanel>
          <TextBlock Text="The aim check measures hands-off center/noise, full stick range, XInput motion updates, Flydigi runtime state, duplicate/remapped inputs, Steam Input risk, and readable Halo controller values." Foreground="#C8D0DC" TextWrapping="Wrap" Margin="0,8,0,0" MaxWidth="850" HorizontalAlignment="Left"/>
        </StackPanel>
      </TabItem>

      <TabItem Header="Tools">
        <StackPanel Margin="18">
          <TextBlock Text="Performance Tools" FontSize="24" FontWeight="Bold"/>
          <WrapPanel Margin="0,16,0,0">
            <Button Name="LaunchRTSSBtn" Content="Launch RTSS" Width="160" Height="42" Margin="0,0,10,10"/>
            <Button Name="LaunchAfterburnerBtn" Content="Launch MSI Afterburner" Width="190" Height="42" Margin="0,0,10,10"/>
            <Button Name="LaunchCapFrameXBtn" Content="Launch CapFrameX" Width="180" Height="42" Margin="0,0,10,10"/>
          </WrapPanel>
        </StackPanel>
      </TabItem>
    </TabControl>

    <Border Grid.Row="2" Background="#171C24" Padding="12">
      <TextBox Name="LogBox" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Background="#0B0E13" Foreground="#DDE5EE" FontFamily="Consolas"/>
    </Border>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$StatusText = $Window.FindName('StatusText')
$PlatformText = $Window.FindName('PlatformText')
$GamingText = $Window.FindName('GamingText')
$DeviceText = $Window.FindName('DeviceText')
$HealthText = $Window.FindName('HealthText')
$AuditProgress = $Window.FindName('AuditProgress')
$HistoryGrid = $Window.FindName('HistoryGrid')
$LogBox = $Window.FindName('LogBox')

function Add-AppLog([string]$Message) {
    $LogBox.AppendText("[$(Get-Date -Format HH:mm:ss)] $Message`r`n")
    $LogBox.ScrollToEnd()
}

function Refresh-Dashboard {
    $r = Read-LatestAudit
    if (-not $r) {
        $StatusText.Text = 'No audit found'
        $PlatformText.Text = 'Run an audit to populate the dashboard.'
        return
    }
    $PlatformText.Text = "$($r.platform.cpu)`n$($r.platform.gpu)`n$($r.platform.display)`nBIOS $($r.platform.bios)"
    $GamingText.Text = "Power: $($r.gaming.power_plan)`nGame Mode: $($r.gaming.game_mode)`nGame DVR: $($r.gaming.game_dvr)`nHAGS: $($r.gaming.hags)`nMPO: $($r.gaming.mpo_override)"
    $DeviceText.Text = "Flydigi: $($r.devices.flydigi_detected)`nNVIDIA: $($r.devices.nvidia_driver)`nWired: $($r.devices.active_wired_adapters)`nWi-Fi: $($r.devices.active_wifi_adapters)"
    $HealthText.Text = "System errors: $($r.health.system_error_count)`nApplication errors: $($r.health.application_error_count)`nProblem devices: $($r.health.problem_device_count)`nPending reboot: $($r.health.pending_reboot_count)`nFree space: $($r.health.system_drive_free_gb) GB"
    $StatusText.Text = "Latest audit: $($r.audit_id)"
    $HistoryGrid.ItemsSource = @(Get-AuditHistory)
    Add-AppLog "Loaded $($r.audit_id)."
}

function Run-Audit([bool]$Publish) {
    if (-not (Test-Path -LiteralPath $Collector)) {
        [System.Windows.MessageBox]::Show("Collector missing: $Collector",'GPTOPT') | Out-Null
        return
    }
    $Window.Cursor = [Windows.Input.Cursors]::Wait
    $AuditProgress.IsIndeterminate = $true
    $StatusText.Text = if ($Publish) { 'Running and publishing audit...' } else { 'Running local audit...' }
    Add-AppLog $StatusText.Text
    try {
        if ($Publish) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Collector -Publish 2>&1 | ForEach-Object { Add-AppLog $_ } }
        else { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Collector 2>&1 | ForEach-Object { Add-AppLog $_ } }
        $AuditProgress.IsIndeterminate = $false
        $AuditProgress.Value = 100
        Refresh-Dashboard
    } catch {
        Add-AppLog "Audit failed: $($_.Exception.Message)"
        $StatusText.Text = 'Audit failed'
    } finally {
        $AuditProgress.IsIndeterminate = $false
        $Window.Cursor = $null
    }
}

$Window.FindName('RunAuditBtn').Add_Click({ Run-Audit $true })
$Window.FindName('LocalAuditBtn').Add_Click({ Run-Audit $false })
$Window.FindName('RefreshBtn').Add_Click({ Refresh-Dashboard })
$Window.FindName('RefreshHistoryBtn').Add_Click({ $HistoryGrid.ItemsSource = @(Get-AuditHistory); Add-AppLog 'History refreshed.' })
$Window.FindName('OpenAuditFolderBtn').Add_Click({ New-Item -ItemType Directory -Path $AuditRoot -Force | Out-Null; Start-Process explorer.exe $AuditRoot })
$Window.FindName('OpenIssueBtn').Add_Click({ Start-Process 'https://github.com/ShellPower2003/GPTOPT-Gaming-Assistant/issues/30' })
$Window.FindName('OpenSelectedBtn').Add_Click({ if ($HistoryGrid.SelectedItem) { Start-Process explorer.exe $HistoryGrid.SelectedItem.Folder } })
$Window.FindName('OpenHaloSettingsBtn').Add_Click({ $p=Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings'; if(Test-Path $p){Start-Process explorer.exe $p}else{[System.Windows.MessageBox]::Show('Halo settings folder not found.','GPTOPT')|Out-Null} })
$Window.FindName('RunControllerAimBtn').Add_Click({
    if (-not (Test-Path -LiteralPath $ControllerAimCheck)) {
        [System.Windows.MessageBox]::Show("Controller aim diagnostic missing: $ControllerAimCheck",'GPTOPT') | Out-Null
        return
    }
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ControllerAimCheck`"" -WorkingDirectory $Root
    Add-AppLog 'Launched read-only controller aim check.'
})
$Window.FindName('OpenControllerReportsBtn').Add_Click({
    $p=Join-Path $env:USERPROFILE 'Desktop\GPTOPT-Logs\ControllerAim'
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    Start-Process explorer.exe $p
})

function Start-FirstExisting([string[]]$Paths,[string]$Name) {
    $p=$Paths|Where-Object{Test-Path $_}|Select-Object -First 1
    if($p){Start-Process $p;Add-AppLog "Launched $Name."}else{[System.Windows.MessageBox]::Show("$Name was not found.",'GPTOPT')|Out-Null}
}
$Window.FindName('LaunchRTSSBtn').Add_Click({ Start-FirstExisting @("$env:ProgramFiles(x86)\RivaTuner Statistics Server\RTSS.exe","$env:ProgramFiles\RivaTuner Statistics Server\RTSS.exe") 'RTSS' })
$Window.FindName('LaunchAfterburnerBtn').Add_Click({ Start-FirstExisting @("$env:ProgramFiles(x86)\MSI Afterburner\MSIAfterburner.exe") 'MSI Afterburner' })
$Window.FindName('LaunchCapFrameXBtn').Add_Click({ Start-FirstExisting @("$env:ProgramFiles(x86)\CapFrameX\CapFrameX.exe","$env:ProgramFiles\CapFrameX\CapFrameX.exe") 'CapFrameX' })

Refresh-Dashboard
Add-AppLog 'GPTOPT desktop application started.'
$Window.ShowDialog() | Out-Null
