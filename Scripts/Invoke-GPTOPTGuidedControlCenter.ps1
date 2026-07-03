param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

$Root = Split-Path -Parent $PSScriptRoot
$KnowledgeDir = Join-Path $Root 'Knowledge'
$ReportsDir = Join-Path $Root 'Reports'
$HealthModelPath = Join-Path $KnowledgeDir 'gptopt-health-model.json'
$ProfileSchemaPath = Join-Path $KnowledgeDir 'game-profile-schema.json'
$CheckExplanationsPath = Join-Path $KnowledgeDir 'check-explanations.json'
$SafetyScanner = Join-Path $PSScriptRoot 'Test-GPTOPTSafety.ps1'
$AdvancedControlCenter = Join-Path $PSScriptRoot 'Invoke-GPTOPTControlCenter.ps1'
$LegacyControlCenter = Join-Path $PSScriptRoot 'Invoke-GPTOPTAppGUI.ps1'

New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null

function Read-JsonFile {
    param(
        [string]$Path,
        [object]$Fallback
    )

    if (Test-Path -LiteralPath $Path) {
        try {
            return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        } catch {
            return $Fallback
        }
    }

    return $Fallback
}

$CheckExplanationModel = Read-JsonFile -Path $CheckExplanationsPath -Fallback ([pscustomobject]@{})

function Get-CardExplanation {
    param([string]$Area)

    if (
        $CheckExplanationModel.PSObject.Properties.Name -contains 'guidedCards' -and
        $null -ne $CheckExplanationModel.guidedCards.PSObject.Properties[$Area]
    ) {
        return $CheckExplanationModel.guidedCards.PSObject.Properties[$Area].Value
    }

    return [pscustomobject]@{
        label = $Area
        whyItMatters = 'This check helps keep the selected gaming session consistent and explainable.'
        goodState = 'The current state matches the selected profile or is explicitly marked not applicable.'
    }
}

function Get-GuidedProfiles {
    $health = Read-JsonFile -Path $HealthModelPath -Fallback ([pscustomobject]@{})
    $schema = Read-JsonFile -Path $ProfileSchemaPath -Fallback ([pscustomobject]@{})
    $profiles = New-Object System.Collections.Generic.List[object]

    foreach ($profile in @($health.gameProfiles)) {
        if ($null -eq $profile) { continue }
        $routine = @()
        if (
            $profile.PSObject.Properties.Name -contains 'playerLayer' -and
            $profile.playerLayer.PSObject.Properties.Name -contains 'warmup' -and
            $profile.playerLayer.warmup.PSObject.Properties.Name -contains 'defaultRoutine'
        ) {
            $routine = @($profile.playerLayer.warmup.defaultRoutine)
        }
        $profiles.Add([pscustomobject]@{
            Id = [string]$profile.id
            DisplayName = [string]$profile.name
            Status = [string]$profile.status
            Role = [string]$profile.role
            WarmupRoutine = $routine
        })
    }

    foreach ($profile in @($schema.defaultProfiles)) {
        if ($null -eq $profile) { continue }
        if (@($profiles | Where-Object { $_.Id -eq [string]$profile.id }).Count -gt 0) { continue }
        $routine = @()
        if (
            $profile.PSObject.Properties.Name -contains 'warmupRoutine' -and
            $profile.warmupRoutine.PSObject.Properties.Name -contains 'steps'
        ) {
            $routine = @($profile.warmupRoutine.steps | ForEach-Object { [string]$_.name })
        }
        $profiles.Add([pscustomobject]@{
            Id = [string]$profile.id
            DisplayName = [string]$profile.displayName
            Status = [string]$profile.status
            Role = [string]$profile.role
            WarmupRoutine = $routine
        })
    }

    if ($profiles.Count -eq 0) {
        $profiles.Add([pscustomobject]@{
            Id = 'generic.shooter'
            DisplayName = 'Generic Competitive Shooter'
            Status = 'experimental'
            Role = 'fallback profile'
            WarmupRoutine = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
        })
    }

    return @($profiles.ToArray())
}

function Invoke-GuidedAudit {
    if (-not (Test-Path -LiteralPath $SafetyScanner)) {
        throw "Safety scanner not found: $SafetyScanner"
    }

    & $SafetyScanner -Context NormalGaming -AsObject
}

function Test-ProcessRunning {
    param([string]$Name)

    return $null -ne (Get-Process -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Test-CommandAvailable {
    param([string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-SonarState {
    $processNames = @('SteelSeriesGG', 'SteelSeriesSonar', 'SteelSeriesEngine')
    $runningProcess = $processNames |
        Where-Object { Test-ProcessRunning -Name $_ } |
        Select-Object -First 1
    try {
        $sonarDevice = Get-CimInstance -ClassName 'Win32_SoundDevice' -ErrorAction Stop |
            Where-Object { $_.Name -match 'Sonar' } |
            Select-Object -First 1
    } catch {
        $sonarDevice = $null
    }

    $deviceName = if ($sonarDevice) { [string]$sonarDevice.Name } else { '' }
    [pscustomobject]@{
        Available = [bool]($runningProcess -or $sonarDevice)
        Detail = "Process=$runningProcess; VirtualDevice=$deviceName"
    }
}

function Get-HaloSettingsPath {
    Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings\SpecControlSettings.json'
}

function Get-RTSSHaloProfilePath {
    $roots = @(
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        [Environment]::GetEnvironmentVariable('ProgramFiles')
    ) | Where-Object { $_ }

    $candidates = foreach ($programRoot in $roots) {
        Join-Path $programRoot 'RivaTuner Statistics Server\Profiles\HaloInfinite.exe.cfg'
    }

    $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Test-RTSS240Baseline {
    $path = Get-RTSSHaloProfilePath
    if (-not $path) {
        return [pscustomobject]@{ Found = $false; Ready = $false; Detail = 'Halo RTSS profile was not found.' }
    }

    $text = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
    $hasCap = $text -match '(?im)^\s*FramerateLimit\s*=\s*240\s*$'
    $detectLevelTwo = $text -match '(?im)^\s*ApplicationDetectionLevel\s*=\s*2\s*
    param(
        [string]$Area,
        [ValidateSet('Good', 'Review', 'Fix')]
        [string]$Status,
        [string]$Meaning,
        [string]$Action,
        [string]$Risk,
        [string]$UndoPath,
        [string]$Details
    )

    [pscustomobject]@{
        Area = $Area
        Status = $Status
        Meaning = $Meaning
        Action = $Action
        Risk = $Risk
        UndoPath = $UndoPath
        Details = $Details
    }
}

function Convert-AuditToGuidedCards {
    param(
        [object]$Audit,
        [string]$ProfileId
    )

    $cards = New-Object System.Collections.Generic.List[object]
    $checks = @($Audit.Checks)

    $pending = $checks | Where-Object { $_.Id -eq 'pending-reboot' } | Select-Object -First 1
    if ($pending -and $pending.RequiresReboot) {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'Windows Update or servicing is waiting for a reboot. Finish it before controlled benchmarks or ranked play.' -Action 'Restart before the next controlled gaming test.' -Risk 'Low. This completes an existing Windows servicing change.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } elseif ($pending -and $pending.Evidence -match 'Classification=Cleanup') {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'App or driver cleanup file is waiting for reboot. This is usually not a Windows servicing problem.' -Action 'Reboot later if this persists, or after installing drivers/updates.' -Risk 'Low. This does not block play by itself.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } else {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Good' -Meaning 'No pending reboot markers were detected.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details ($pending.Evidence)))
    }

    $windows = @($checks | Where-Object { $_.Id -in @('hags', 'mpo', 'game-mode', 'game-dvr') })
    $windowsReady = (
        ($windows | Where-Object { $_.Id -eq 'hags' }).Status -eq 'HwSchMode=2' -and
        ($windows | Where-Object { $_.Id -eq 'mpo' }).Status -eq 'OverlayTestMode=5' -and
        ($windows | Where-Object { $_.Id -eq 'game-mode' }).Status -eq 'AutoGameModeEnabled=1' -and
        ($windows | Where-Object { $_.Id -eq 'game-dvr' }).Status -eq 'GameDVR_Enabled=0'
    )
    if ($windowsReady) {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Good' -Meaning 'Windows graphics, Game Mode, and capture settings match the gaming baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    } else {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Review' -Meaning 'One or more Windows gaming settings are outside the selected baseline or could not be read.' -Action 'Review details before considering a backed-up change.' -Risk 'Medium-low if changed later; this audit is read-only.' -UndoPath 'Future write actions must export the affected registry keys first.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    }

    $rtssState = Test-RTSS240Baseline
    if ($ProfileId -eq 'halo.infinite') {
        if ($rtssState.Ready) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Good' -Meaning 'Halo is already set up for the RTSS 240 FPS baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details $rtssState.Detail))
        } elseif ($rtssState.Found) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'RTSS has a Halo profile, but it does not clearly match the 240 FPS baseline.' -Action 'Review the recommended queue item before changing the RTSS profile.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Restore the backed-up HaloInfinite.exe.cfg profile.' -Details $rtssState.Detail))
        } else {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'GPTOPT did not find a Halo-specific RTSS profile. The app can still run, but the 240 FPS limiter baseline is not confirmed.' -Action 'Install/start RTSS or create the Halo RTSS profile only if you use RTSS as the limiter.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Remove the generated RTSS profile or restore its backup.' -Details $rtssState.Detail))
        }
    } else {
        $cards.Add((New-Card -Area 'FPS Limiter' -Status 'Review' -Meaning 'This profile does not have a dedicated limiter rule yet.' -Action 'Use the game-specific limiter policy before stacking RTSS, in-game, or driver caps.' -Risk 'Low for review. Actual limiter changes must be backed up or documented.' -UndoPath 'Revert the limiter profile that was changed.' -Details 'Generic profile selected. No game-specific RTSS profile was inspected.'))
    }

    $haloSettings = Get-HaloSettingsPath
    if ($ProfileId -eq 'halo.infinite') {
        if (Test-Path -LiteralPath $haloSettings) {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were found. Guided Mode does not edit them during audit.' -Action 'Use the recommended queue only after reading backup and undo details.' -Risk 'Low if applied later with SpecControlSettings.json backup.' -UndoPath 'Restore the backed-up SpecControlSettings.json file.' -Details "Path=$haloSettings"))
        } else {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were not found. This is expected if Halo has not been installed or launched on this Windows profile.' -Action 'No fix required unless you are preparing a Halo session.' -Risk 'None.' -UndoPath 'Not required.' -Details "Missing path=$haloSettings"))
        }
    }

    $sonar = Get-SonarState
    if ($sonar.Available) {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Good' -Meaning 'SteelSeries Sonar is available through its app process or virtual audio device.' -Action 'No action needed unless routing sounds wrong.' -Risk 'None.' -UndoPath 'Not required.' -Details $sonar.Detail))
    } else {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Review' -Meaning 'Sonar was not detected as a running app or virtual audio device. This is fine if you do not use Sonar.' -Action 'Open SteelSeries GG only if Sonar is part of this profile.' -Risk 'Low.' -UndoPath 'Close SteelSeries GG.' -Details $sonar.Detail))
    }

    $tools = @(
        "RTSS running=$(Test-ProcessRunning -Name 'RTSS')",
        "MSI Afterburner running=$(Test-ProcessRunning -Name 'MSIAfterburner')",
        "Flydigi app running=$(Test-ProcessRunning -Name 'FlydigiSpaceStation')",
        "CapFrameX available=$(Test-CommandAvailable -Name 'CapFrameX.exe')",
        "PresentMon available=$(Test-CommandAvailable -Name 'PresentMon.exe')"
    )
    $cards.Add((New-Card -Area 'Optional Session Tools' -Status 'Good' -Meaning 'Optional tools were checked without treating missing apps as a readiness failure.' -Action 'Open only the tools you intentionally use for this session.' -Risk 'Low.' -UndoPath 'Close the app you opened.' -Details ($tools -join "`r`n")))

    return @($cards.ToArray())
}

function New-ActionItem {
    param(
        [string]$Name,
        [string]$WhatChanges,
        [string]$WhyItMatters,
        [string]$Risk,
        [string]$BackupUndo,
        [bool]$RequiresReboot
    )

    [pscustomobject]@{
        Action = $Name
        WhatItChanges = $WhatChanges
        WhyItMatters = $WhyItMatters
        Risk = $Risk
        BackupUndoPath = $BackupUndo
        RequiresReboot = if ($RequiresReboot) { 'Yes' } else { 'No' }
        Status = 'Preview only. Not applied from Guided Mode.'
    }
}

function Get-RecommendedActionQueue {
    param(
        [object[]]$Cards,
        [string]$ProfileId
    )

    $items = New-Object System.Collections.Generic.List[object]
    if (@($Cards | Where-Object { $_.Area -eq 'Windows Reboot State' -and $_.Details -match 'Classification=Servicing' }).Count -gt 0) {
        $items.Add((New-ActionItem -Name 'Finish Pending Reboot' -WhatChanges 'Nothing inside GPTOPT. You decide when to reboot Windows.' -WhyItMatters 'A pending reboot can make benchmark results and driver state inconsistent.' -Risk 'Low' -BackupUndo 'No GPTOPT backup required because GPTOPT does not start the reboot.' -RequiresReboot $true))
    }

    $items.Add((New-ActionItem -Name 'Save Readiness Report' -WhatChanges 'Writes a Markdown readiness summary under the repo Reports folder.' -WhyItMatters 'Gives you a before/after record without changing Windows, Halo, or tool settings.' -Risk 'Low' -BackupUndo 'Delete the generated report if you do not need it.' -RequiresReboot $false))

    if ($ProfileId -eq 'halo.infinite') {
        $items.Add((New-ActionItem -Name 'Apply RTSS Halo 240 Cap' -WhatChanges 'Would update only the Halo RTSS profile to use a 240 FPS cap and enabled detection.' -WhyItMatters 'Keeps the FPS limiter consistent with the current competitive baseline.' -Risk 'Low' -BackupUndo 'Back up HaloInfinite.exe.cfg first; undo by restoring that file.' -RequiresReboot $false))
        $items.Add((New-ActionItem -Name 'Apply Halo Display Baseline' -WhatChanges 'Would change only listed Halo display/session fields in SpecControlSettings.json.' -WhyItMatters 'Keeps Halo display behavior aligned with the selected competitive profile.' -Risk 'Low' -BackupUndo 'Back up SpecControlSettings.json first; undo by restoring that backup.' -RequiresReboot $false))
    }

    $items.Add((New-ActionItem -Name 'Open Session Apps' -WhatChanges 'Starts existing tools such as RTSS, Sonar, or controller software only when you choose them.' -WhyItMatters 'Confirms the same app stack is active before you judge game feel.' -Risk 'Low' -BackupUndo 'Close the app or disable its own startup option.' -RequiresReboot $false))

    return @($items.ToArray())
}

function Get-ReadinessVerdict {
    param([object[]]$Cards)

    if (@($Cards | Where-Object { $_.Status -eq 'Fix' }).Count -gt 0) { return 'Fix First' }
    if (@($Cards | Where-Object { $_.Status -eq 'Review' }).Count -gt 0) { return 'Ready with Review Items' }
    return 'Ready to Play'
}

function Write-GuidedReport {
    param(
        [object[]]$Cards,
        [object[]]$Queue,
        [string]$Verdict,
        [string]$ProfileName,
        [object[]]$RoutineSteps = @(),
        [string]$SessionFocus = ''
    )

    $path = Join-Path $ReportsDir ("GPTOPT-GuidedReadiness_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $lines = @(
        '# GPTOPT Guided Readiness',
        '',
        "- Generated: $((Get-Date).ToString('o'))",
        "- Profile: $ProfileName",
        "- Verdict: $Verdict",
        '',
        '## Readiness Cards'
    )
    foreach ($card in $Cards) {
        $explanation = Get-CardExplanation -Area $card.Area
        $lines += "- $($explanation.label)"
        $lines += "  - Current status: $($card.Status)"
        $lines += "  - Summary: $($card.Meaning)"
        $lines += "  - Why it matters: $($explanation.whyItMatters)"
        $lines += "  - Good state: $($explanation.goodState)"
        $lines += "  - Safe action: $($card.Action)"
        $lines += "  - Risk: $($card.Risk)"
        $lines += "  - Undo path: $($card.UndoPath)"
    }
    $lines += ''
    $lines += '## Recommended Action Queue'
    foreach ($item in $Queue) {
        $lines += "- $($item.Action): changes=$($item.WhatItChanges); why=$($item.WhyItMatters); risk=$($item.Risk); undo=$($item.BackupUndoPath); reboot=$($item.RequiresReboot); status=$($item.Status)"
    }
    $lines += ''
    $lines += '## Pre-Game Routine'
    foreach ($step in $RoutineSteps) {
        $mark = if ($step.Complete) { 'x' } else { ' ' }
        $lines += "- [$mark] $($step.Name)"
    }
    if ($SessionFocus.Trim()) {
        $lines += ''
        $lines += "Session focus: $($SessionFocus.Trim())"
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Set-TextBoxLines {
    param(
        [object]$TextBox,
        [string[]]$Lines
    )

    $TextBox.Text = ($Lines -join "`r`n")
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="GPTOPT Guided Control Center" Height="760" Width="1040" WindowStartupLocation="CenterScreen" Background="#101214">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" LastChildFill="True">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
        <Button Name="AdvancedBtn" Content="Advanced Control Center" Width="190" Height="36" Margin="8,0,0,0"/>
        <Button Name="ReportBtn" Content="Save Report" Width="120" Height="36" Margin="8,0,0,0"/>
      </StackPanel>
      <StackPanel>
        <TextBlock Text="GPTOPT Guided Control Center" FontSize="28" FontWeight="Bold" Foreground="#F4F4F4"/>
        <TextBlock Text="Plain-language readiness for competitive PC gaming. Audit and preview only." Foreground="#B8C0C8" Margin="0,4,0,0"/>
      </StackPanel>
    </DockPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,16,0,12">
      <TextBlock Text="Game Profile" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <ComboBox Name="ProfileBox" Width="260" Height="32"/>
      <Button Name="AuditBtn" Content="Run Audit" Width="120" Height="34" Margin="12,0,0,0"/>
      <CheckBox Name="DetailsToggle" Content="Show Details" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="18,0,0,0"/>
    </StackPanel>
    <TabControl Grid.Row="2" Name="MainTabs" Background="#101214" Foreground="#F4F4F4">
      <TabItem Header="Readiness">
       <Grid Margin="8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Margin="0,0,12,0">
        <UniformGrid Columns="3" Margin="0,0,0,12">
          <Border Name="ReadyCard" BorderBrush="#2E7D32" BorderThickness="1" Background="#172019" Padding="12" Margin="0,0,8,0">
            <StackPanel><TextBlock Text="Ready to Play" FontWeight="Bold" Foreground="#DDF5DE"/><TextBlock Name="ReadyCount" Text="0" FontSize="28" Foreground="#DDF5DE"/></StackPanel>
          </Border>
          <Border Name="ReviewCard" BorderBrush="#B8860B" BorderThickness="1" Background="#211D12" Padding="12" Margin="4,0,4,0">
            <StackPanel><TextBlock Text="Ready with Review Items" FontWeight="Bold" Foreground="#FFE6A3"/><TextBlock Name="ReviewCount" Text="0" FontSize="28" Foreground="#FFE6A3"/></StackPanel>
          </Border>
          <Border Name="FixCard" BorderBrush="#B23B3B" BorderThickness="1" Background="#241515" Padding="12" Margin="8,0,0,0">
            <StackPanel><TextBlock Text="Fix First" FontWeight="Bold" Foreground="#FFD5D5"/><TextBlock Name="FixCount" Text="0" FontSize="28" Foreground="#FFD5D5"/></StackPanel>
          </Border>
        </UniformGrid>
        <TextBlock Name="VerdictText" Text="Run an audit to check readiness." FontSize="20" FontWeight="Bold" Foreground="#F4F4F4" Margin="0,0,0,8"/>
        <TextBox Name="CardsBox" Height="410" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <TextBlock Text="Recommended Action Queue" FontSize="18" FontWeight="Bold" Foreground="#F4F4F4"/>
          <TextBox Name="QueueBox" Height="500" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
        </StackPanel>
       </Grid>
      </TabItem>
      <TabItem Header="Pre-Game Routine">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" LastChildFill="True">
            <Button Name="ResetRoutineBtn" DockPanel.Dock="Right" Content="Reset" Width="90" Height="32" Margin="8,0,0,0"/>
            <StackPanel>
              <TextBlock Text="Pre-Game Routine" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBlock Name="RoutineProgressText" Text="0 of 0 complete" Foreground="#B8C0C8" Margin="0,4,0,0"/>
            </StackPanel>
          </DockPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,14,0,14">
            <StackPanel Name="RoutineStepsPanel"/>
          </ScrollViewer>
          <StackPanel Grid.Row="2">
            <TextBlock Text="Session Focus" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBox Name="SessionFocusBox" Height="56" TextWrapping="Wrap" AcceptsReturn="True" Background="#080A0C" Foreground="#ECEFF1" Margin="0,6,0,0" ToolTip="One specific thing to focus on this session."/>
          </StackPanel>
        </Grid>
      </TabItem>
    </TabControl>
    <DockPanel Grid.Row="3" Margin="0,12,0,0">
      <TextBlock DockPanel.Dock="Top" Text="Details" FontWeight="Bold" Foreground="#F4F4F4"/>
      <TextBox Name="DetailsBox" Visibility="Collapsed" IsReadOnly="True" TextWrapping="NoWrap" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#C9D1D9" FontFamily="Consolas"/>
    </DockPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$ProfileBox = $Window.FindName('ProfileBox')
$ReadyCount = $Window.FindName('ReadyCount')
$ReviewCount = $Window.FindName('ReviewCount')
$FixCount = $Window.FindName('FixCount')
$VerdictText = $Window.FindName('VerdictText')
$CardsBox = $Window.FindName('CardsBox')
$QueueBox = $Window.FindName('QueueBox')
$DetailsBox = $Window.FindName('DetailsBox')
$DetailsToggle = $Window.FindName('DetailsToggle')
$RoutineStepsPanel = $Window.FindName('RoutineStepsPanel')
$RoutineProgressText = $Window.FindName('RoutineProgressText')
$SessionFocusBox = $Window.FindName('SessionFocusBox')

$Profiles = @(Get-GuidedProfiles)
foreach ($profile in $Profiles) {
    [void]$ProfileBox.Items.Add($profile.DisplayName)
}
$ProfileBox.SelectedIndex = 0

$script:LastCards = @()
$script:LastQueue = @()
$script:LastVerdict = 'Not audited'
$script:LastProfileName = [string]$Profiles[0].DisplayName

function Get-SelectedProfile {
    $index = $ProfileBox.SelectedIndex
    if ($index -lt 0) { $index = 0 }
    $Profiles[$index]
}

function Get-CurrentRoutineState {
    foreach ($checkBox in @($RoutineStepsPanel.Children)) {
        [pscustomobject]@{
            Name = [string]$checkBox.Content
            Complete = [bool]$checkBox.IsChecked
        }
    }
}

function Update-RoutineProgress {
    $steps = @(Get-CurrentRoutineState)
    $complete = @($steps | Where-Object { $_.Complete }).Count
    $RoutineProgressText.Text = "$complete of $($steps.Count) complete"
    if ($steps.Count -gt 0 -and $complete -eq $steps.Count) {
        $RoutineProgressText.Text += ' - ready to queue'
        $RoutineProgressText.Foreground = '#9BE39F'
    } else {
        $RoutineProgressText.Foreground = '#B8C0C8'
    }
}

function Initialize-Routine {
    $RoutineStepsPanel.Children.Clear()
    $profile = Get-SelectedProfile
    $steps = @($profile.WarmupRoutine | Where-Object { $_ })
    if ($steps.Count -eq 0) {
        $steps = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
    }

    foreach ($step in $steps) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = [string]$step
        $checkBox.Foreground = '#F4F4F4'
        $checkBox.FontSize = 16
        $checkBox.Margin = '0,0,0,12'
        $checkBox.Add_Checked({ Update-RoutineProgress })
        $checkBox.Add_Unchecked({ Update-RoutineProgress })
        [void]$RoutineStepsPanel.Children.Add($checkBox)
    }
    Update-RoutineProgress
}

function Refresh-GuidedView {
    $profile = Get-SelectedProfile
    $script:LastProfileName = [string]$profile.DisplayName
    $audit = Invoke-GuidedAudit
    $cards = @(Convert-AuditToGuidedCards -Audit $audit -ProfileId $profile.Id)
    $queue = @(Get-RecommendedActionQueue -Cards $cards -ProfileId $profile.Id)
    $verdict = Get-ReadinessVerdict -Cards $cards

    $script:LastCards = $cards
    $script:LastQueue = $queue
    $script:LastVerdict = $verdict

    $ReadyCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Good' }).Count
    $ReviewCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Review' }).Count
    $FixCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Fix' }).Count
    $VerdictText.Text = "$verdict - $($profile.DisplayName)"

    $cardLines = foreach ($card in $cards) {
        $explanation = Get-CardExplanation -Area $card.Area
        "$($explanation.label)`r`n  Current status: $($card.Status)`r`n  Summary: $($card.Meaning)`r`n  Why it matters: $($explanation.whyItMatters)`r`n  Good state: $($explanation.goodState)`r`n  Safe action: $($card.Action)`r`n  Risk: $($card.Risk)`r`n  Undo path: $($card.UndoPath)`r`n"
    }
    Set-TextBoxLines -TextBox $CardsBox -Lines $cardLines

    $queueLines = foreach ($item in $queue) {
        "$($item.Action)`r`n  What it changes: $($item.WhatItChanges)`r`n  Why it matters: $($item.WhyItMatters)`r`n  Risk: $($item.Risk)`r`n  Backup/undo path: $($item.BackupUndoPath)`r`n  Reboot required: $($item.RequiresReboot)`r`n  Status: $($item.Status)`r`n"
    }
    Set-TextBoxLines -TextBox $QueueBox -Lines $queueLines

    $detailLines = @(
        "Profile: $($profile.Id)",
        "Audit generated: $($audit.GeneratedAt)",
        '',
        'Raw card evidence:'
    )
    foreach ($card in $cards) {
        $detailLines += "[$($card.Area)] $($card.Details)"
    }
    Set-TextBoxLines -TextBox $DetailsBox -Lines $detailLines
}

$Window.FindName('AuditBtn').Add_Click({
    try {
        Refresh-GuidedView
    } catch {
        $VerdictText.Text = 'Audit failed before readiness could be calculated.'
        $CardsBox.Text = $_.Exception.Message
    }
})

$Window.FindName('ReportBtn').Add_Click({
    try {
        if ($script:LastCards.Count -eq 0) { Refresh-GuidedView }
        $path = Write-GuidedReport -Cards $script:LastCards -Queue $script:LastQueue -Verdict $script:LastVerdict -ProfileName $script:LastProfileName -RoutineSteps @(Get-CurrentRoutineState) -SessionFocus $SessionFocusBox.Text
        [System.Windows.MessageBox]::Show("Report saved:`r`n$path", 'GPTOPT Guided Control Center') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Guided Control Center') | Out-Null
    }
})

$Window.FindName('AdvancedBtn').Add_Click({
    $entry = if (Test-Path -LiteralPath $AdvancedControlCenter) { $AdvancedControlCenter } else { $LegacyControlCenter }
    if (Test-Path -LiteralPath $entry) {
        Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$entry`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show('Advanced Control Center entry was not found.', 'GPTOPT Guided Control Center') | Out-Null
    }
})

$DetailsToggle.Add_Checked({ $DetailsBox.Visibility = 'Visible' })
$DetailsToggle.Add_Unchecked({ $DetailsBox.Visibility = 'Collapsed' })
$Window.FindName('ResetRoutineBtn').Add_Click({ Initialize-Routine; $SessionFocusBox.Clear() })
$ProfileBox.Add_SelectionChanged({
    if ($ProfileBox.SelectedIndex -ge 0) {
        Initialize-Routine
        Refresh-GuidedView
    }
})

Initialize-Routine
Refresh-GuidedView
$Window.ShowDialog() | Out-Null


    [pscustomobject]@{
        Found = $true
        Ready = ($hasCap -and $detectLevelTwo)
        Detail = "Profile=$path; FramerateLimit240=$hasCap; ApplicationDetectionLevel2=$detectLevelTwo"
    }
}

function New-Card {
    param(
        [string]$Area,
        [ValidateSet('Good', 'Review', 'Fix')]
        [string]$Status,
        [string]$Meaning,
        [string]$Action,
        [string]$Risk,
        [string]$UndoPath,
        [string]$Details
    )

    [pscustomobject]@{
        Area = $Area
        Status = $Status
        Meaning = $Meaning
        Action = $Action
        Risk = $Risk
        UndoPath = $UndoPath
        Details = $Details
    }
}

function Convert-AuditToGuidedCards {
    param(
        [object]$Audit,
        [string]$ProfileId
    )

    $cards = New-Object System.Collections.Generic.List[object]
    $checks = @($Audit.Checks)

    $pending = $checks | Where-Object { $_.Id -eq 'pending-reboot' } | Select-Object -First 1
    if ($pending -and $pending.RequiresReboot) {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'Windows Update or servicing is waiting for a reboot. Finish it before controlled benchmarks or ranked play.' -Action 'Restart before the next controlled gaming test.' -Risk 'Low. This completes an existing Windows servicing change.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } elseif ($pending -and $pending.Evidence -match 'Classification=Cleanup') {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'App or driver cleanup file is waiting for reboot. This is usually not a Windows servicing problem.' -Action 'Reboot later if this persists, or after installing drivers/updates.' -Risk 'Low. This does not block play by itself.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } else {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Good' -Meaning 'No pending reboot markers were detected.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details ($pending.Evidence)))
    }

    $windows = @($checks | Where-Object { $_.Id -in @('hags', 'mpo', 'game-mode', 'game-dvr') })
    $windowsReady = (
        ($windows | Where-Object { $_.Id -eq 'hags' }).Status -eq 'HwSchMode=2' -and
        ($windows | Where-Object { $_.Id -eq 'mpo' }).Status -eq 'OverlayTestMode=5' -and
        ($windows | Where-Object { $_.Id -eq 'game-mode' }).Status -eq 'AutoGameModeEnabled=1' -and
        ($windows | Where-Object { $_.Id -eq 'game-dvr' }).Status -eq 'GameDVR_Enabled=0'
    )
    if ($windowsReady) {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Good' -Meaning 'Windows graphics, Game Mode, and capture settings match the gaming baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    } else {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Review' -Meaning 'One or more Windows gaming settings are outside the selected baseline or could not be read.' -Action 'Review details before considering a backed-up change.' -Risk 'Medium-low if changed later; this audit is read-only.' -UndoPath 'Future write actions must export the affected registry keys first.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    }

    $rtssState = Test-RTSS240Baseline
    if ($ProfileId -eq 'halo.infinite') {
        if ($rtssState.Ready) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Good' -Meaning 'Halo is already set up for the RTSS 240 FPS baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details $rtssState.Detail))
        } elseif ($rtssState.Found) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'RTSS has a Halo profile, but it does not clearly match the 240 FPS baseline.' -Action 'Review the recommended queue item before changing the RTSS profile.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Restore the backed-up HaloInfinite.exe.cfg profile.' -Details $rtssState.Detail))
        } else {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'GPTOPT did not find a Halo-specific RTSS profile. The app can still run, but the 240 FPS limiter baseline is not confirmed.' -Action 'Install/start RTSS or create the Halo RTSS profile only if you use RTSS as the limiter.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Remove the generated RTSS profile or restore its backup.' -Details $rtssState.Detail))
        }
    } else {
        $cards.Add((New-Card -Area 'FPS Limiter' -Status 'Review' -Meaning 'This profile does not have a dedicated limiter rule yet.' -Action 'Use the game-specific limiter policy before stacking RTSS, in-game, or driver caps.' -Risk 'Low for review. Actual limiter changes must be backed up or documented.' -UndoPath 'Revert the limiter profile that was changed.' -Details 'Generic profile selected. No game-specific RTSS profile was inspected.'))
    }

    $haloSettings = Get-HaloSettingsPath
    if ($ProfileId -eq 'halo.infinite') {
        if (Test-Path -LiteralPath $haloSettings) {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were found. Guided Mode does not edit them during audit.' -Action 'Use the recommended queue only after reading backup and undo details.' -Risk 'Low if applied later with SpecControlSettings.json backup.' -UndoPath 'Restore the backed-up SpecControlSettings.json file.' -Details "Path=$haloSettings"))
        } else {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were not found. This is expected if Halo has not been installed or launched on this Windows profile.' -Action 'No fix required unless you are preparing a Halo session.' -Risk 'None.' -UndoPath 'Not required.' -Details "Missing path=$haloSettings"))
        }
    }

    $sonar = Get-SonarState
    if ($sonar.Available) {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Good' -Meaning 'SteelSeries Sonar is available through its app process or virtual audio device.' -Action 'No action needed unless routing sounds wrong.' -Risk 'None.' -UndoPath 'Not required.' -Details $sonar.Detail))
    } else {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Review' -Meaning 'Sonar was not detected as a running app or virtual audio device. This is fine if you do not use Sonar.' -Action 'Open SteelSeries GG only if Sonar is part of this profile.' -Risk 'Low.' -UndoPath 'Close SteelSeries GG.' -Details $sonar.Detail))
    }

    $tools = @(
        "RTSS running=$(Test-ProcessRunning -Name 'RTSS')",
        "MSI Afterburner running=$(Test-ProcessRunning -Name 'MSIAfterburner')",
        "Flydigi app running=$(Test-ProcessRunning -Name 'FlydigiSpaceStation')",
        "CapFrameX available=$(Test-CommandAvailable -Name 'CapFrameX.exe')",
        "PresentMon available=$(Test-CommandAvailable -Name 'PresentMon.exe')"
    )
    $cards.Add((New-Card -Area 'Optional Session Tools' -Status 'Good' -Meaning 'Optional tools were checked without treating missing apps as a readiness failure.' -Action 'Open only the tools you intentionally use for this session.' -Risk 'Low.' -UndoPath 'Close the app you opened.' -Details ($tools -join "`r`n")))

    return @($cards.ToArray())
}

function New-ActionItem {
    param(
        [string]$Name,
        [string]$WhatChanges,
        [string]$WhyItMatters,
        [string]$Risk,
        [string]$BackupUndo,
        [bool]$RequiresReboot
    )

    [pscustomobject]@{
        Action = $Name
        WhatItChanges = $WhatChanges
        WhyItMatters = $WhyItMatters
        Risk = $Risk
        BackupUndoPath = $BackupUndo
        RequiresReboot = if ($RequiresReboot) { 'Yes' } else { 'No' }
        Status = 'Preview only. Not applied from Guided Mode.'
    }
}

function Get-RecommendedActionQueue {
    param(
        [object[]]$Cards,
        [string]$ProfileId
    )

    $items = New-Object System.Collections.Generic.List[object]
    if (@($Cards | Where-Object { $_.Area -eq 'Windows Reboot State' -and $_.Details -match 'Classification=Servicing' }).Count -gt 0) {
        $items.Add((New-ActionItem -Name 'Finish Pending Reboot' -WhatChanges 'Nothing inside GPTOPT. You decide when to reboot Windows.' -WhyItMatters 'A pending reboot can make benchmark results and driver state inconsistent.' -Risk 'Low' -BackupUndo 'No GPTOPT backup required because GPTOPT does not start the reboot.' -RequiresReboot $true))
    }

    $items.Add((New-ActionItem -Name 'Save Readiness Report' -WhatChanges 'Writes a Markdown readiness summary under the repo Reports folder.' -WhyItMatters 'Gives you a before/after record without changing Windows, Halo, or tool settings.' -Risk 'Low' -BackupUndo 'Delete the generated report if you do not need it.' -RequiresReboot $false))

    if ($ProfileId -eq 'halo.infinite') {
        $items.Add((New-ActionItem -Name 'Apply RTSS Halo 240 Cap' -WhatChanges 'Would update only the Halo RTSS profile to use a 240 FPS cap and enabled detection.' -WhyItMatters 'Keeps the FPS limiter consistent with the current competitive baseline.' -Risk 'Low' -BackupUndo 'Back up HaloInfinite.exe.cfg first; undo by restoring that file.' -RequiresReboot $false))
        $items.Add((New-ActionItem -Name 'Apply Halo Display Baseline' -WhatChanges 'Would change only listed Halo display/session fields in SpecControlSettings.json.' -WhyItMatters 'Keeps Halo display behavior aligned with the selected competitive profile.' -Risk 'Low' -BackupUndo 'Back up SpecControlSettings.json first; undo by restoring that backup.' -RequiresReboot $false))
    }

    $items.Add((New-ActionItem -Name 'Open Session Apps' -WhatChanges 'Starts existing tools such as RTSS, Sonar, or controller software only when you choose them.' -WhyItMatters 'Confirms the same app stack is active before you judge game feel.' -Risk 'Low' -BackupUndo 'Close the app or disable its own startup option.' -RequiresReboot $false))

    return @($items.ToArray())
}

function Get-ReadinessVerdict {
    param([object[]]$Cards)

    if (@($Cards | Where-Object { $_.Status -eq 'Fix' }).Count -gt 0) { return 'Fix First' }
    if (@($Cards | Where-Object { $_.Status -eq 'Review' }).Count -gt 0) { return 'Ready with Review Items' }
    return 'Ready to Play'
}

function Write-GuidedReport {
    param(
        [object[]]$Cards,
        [object[]]$Queue,
        [string]$Verdict,
        [string]$ProfileName,
        [object[]]$RoutineSteps = @(),
        [string]$SessionFocus = ''
    )

    $path = Join-Path $ReportsDir ("GPTOPT-GuidedReadiness_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $lines = @(
        '# GPTOPT Guided Readiness',
        '',
        "- Generated: $((Get-Date).ToString('o'))",
        "- Profile: $ProfileName",
        "- Verdict: $Verdict",
        '',
        '## Readiness Cards'
    )
    foreach ($card in $Cards) {
        $lines += "- [$($card.Status)] $($card.Area): $($card.Meaning) Action: $($card.Action)"
    }
    $lines += ''
    $lines += '## Recommended Action Queue'
    foreach ($item in $Queue) {
        $lines += "- $($item.Action): changes=$($item.WhatItChanges); why=$($item.WhyItMatters); risk=$($item.Risk); undo=$($item.BackupUndoPath); reboot=$($item.RequiresReboot); status=$($item.Status)"
    }
    $lines += ''
    $lines += '## Pre-Game Routine'
    foreach ($step in $RoutineSteps) {
        $mark = if ($step.Complete) { 'x' } else { ' ' }
        $lines += "- [$mark] $($step.Name)"
    }
    if ($SessionFocus.Trim()) {
        $lines += ''
        $lines += "Session focus: $($SessionFocus.Trim())"
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Set-TextBoxLines {
    param(
        [object]$TextBox,
        [string[]]$Lines
    )

    $TextBox.Text = ($Lines -join "`r`n")
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="GPTOPT Guided Control Center" Height="760" Width="1040" WindowStartupLocation="CenterScreen" Background="#101214">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" LastChildFill="True">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
        <Button Name="AdvancedBtn" Content="Advanced Control Center" Width="190" Height="36" Margin="8,0,0,0"/>
        <Button Name="ReportBtn" Content="Save Report" Width="120" Height="36" Margin="8,0,0,0"/>
      </StackPanel>
      <StackPanel>
        <TextBlock Text="GPTOPT Guided Control Center" FontSize="28" FontWeight="Bold" Foreground="#F4F4F4"/>
        <TextBlock Text="Plain-language readiness for competitive PC gaming. Audit and preview only." Foreground="#B8C0C8" Margin="0,4,0,0"/>
      </StackPanel>
    </DockPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,16,0,12">
      <TextBlock Text="Game Profile" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <ComboBox Name="ProfileBox" Width="260" Height="32"/>
      <Button Name="AuditBtn" Content="Run Audit" Width="120" Height="34" Margin="12,0,0,0"/>
      <CheckBox Name="DetailsToggle" Content="Show Details" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="18,0,0,0"/>
    </StackPanel>
    <TabControl Grid.Row="2" Name="MainTabs" Background="#101214" Foreground="#F4F4F4">
      <TabItem Header="Readiness">
       <Grid Margin="8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Margin="0,0,12,0">
        <UniformGrid Columns="3" Margin="0,0,0,12">
          <Border Name="ReadyCard" BorderBrush="#2E7D32" BorderThickness="1" Background="#172019" Padding="12" Margin="0,0,8,0">
            <StackPanel><TextBlock Text="Ready to Play" FontWeight="Bold" Foreground="#DDF5DE"/><TextBlock Name="ReadyCount" Text="0" FontSize="28" Foreground="#DDF5DE"/></StackPanel>
          </Border>
          <Border Name="ReviewCard" BorderBrush="#B8860B" BorderThickness="1" Background="#211D12" Padding="12" Margin="4,0,4,0">
            <StackPanel><TextBlock Text="Ready with Review Items" FontWeight="Bold" Foreground="#FFE6A3"/><TextBlock Name="ReviewCount" Text="0" FontSize="28" Foreground="#FFE6A3"/></StackPanel>
          </Border>
          <Border Name="FixCard" BorderBrush="#B23B3B" BorderThickness="1" Background="#241515" Padding="12" Margin="8,0,0,0">
            <StackPanel><TextBlock Text="Fix First" FontWeight="Bold" Foreground="#FFD5D5"/><TextBlock Name="FixCount" Text="0" FontSize="28" Foreground="#FFD5D5"/></StackPanel>
          </Border>
        </UniformGrid>
        <TextBlock Name="VerdictText" Text="Run an audit to check readiness." FontSize="20" FontWeight="Bold" Foreground="#F4F4F4" Margin="0,0,0,8"/>
        <TextBox Name="CardsBox" Height="410" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <TextBlock Text="Recommended Action Queue" FontSize="18" FontWeight="Bold" Foreground="#F4F4F4"/>
          <TextBox Name="QueueBox" Height="500" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
        </StackPanel>
       </Grid>
      </TabItem>
      <TabItem Header="Pre-Game Routine">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" LastChildFill="True">
            <Button Name="ResetRoutineBtn" DockPanel.Dock="Right" Content="Reset" Width="90" Height="32" Margin="8,0,0,0"/>
            <StackPanel>
              <TextBlock Text="Pre-Game Routine" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBlock Name="RoutineProgressText" Text="0 of 0 complete" Foreground="#B8C0C8" Margin="0,4,0,0"/>
            </StackPanel>
          </DockPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,14,0,14">
            <StackPanel Name="RoutineStepsPanel"/>
          </ScrollViewer>
          <StackPanel Grid.Row="2">
            <TextBlock Text="Session Focus" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBox Name="SessionFocusBox" Height="56" TextWrapping="Wrap" AcceptsReturn="True" Background="#080A0C" Foreground="#ECEFF1" Margin="0,6,0,0" ToolTip="One specific thing to focus on this session."/>
          </StackPanel>
        </Grid>
      </TabItem>
    </TabControl>
    <DockPanel Grid.Row="3" Margin="0,12,0,0">
      <TextBlock DockPanel.Dock="Top" Text="Details" FontWeight="Bold" Foreground="#F4F4F4"/>
      <TextBox Name="DetailsBox" Visibility="Collapsed" IsReadOnly="True" TextWrapping="NoWrap" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#C9D1D9" FontFamily="Consolas"/>
    </DockPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$ProfileBox = $Window.FindName('ProfileBox')
$ReadyCount = $Window.FindName('ReadyCount')
$ReviewCount = $Window.FindName('ReviewCount')
$FixCount = $Window.FindName('FixCount')
$VerdictText = $Window.FindName('VerdictText')
$CardsBox = $Window.FindName('CardsBox')
$QueueBox = $Window.FindName('QueueBox')
$DetailsBox = $Window.FindName('DetailsBox')
$DetailsToggle = $Window.FindName('DetailsToggle')
$RoutineStepsPanel = $Window.FindName('RoutineStepsPanel')
$RoutineProgressText = $Window.FindName('RoutineProgressText')
$SessionFocusBox = $Window.FindName('SessionFocusBox')

$Profiles = @(Get-GuidedProfiles)
foreach ($profile in $Profiles) {
    [void]$ProfileBox.Items.Add($profile.DisplayName)
}
$ProfileBox.SelectedIndex = 0

$script:LastCards = @()
$script:LastQueue = @()
$script:LastVerdict = 'Not audited'
$script:LastProfileName = [string]$Profiles[0].DisplayName

function Get-SelectedProfile {
    $index = $ProfileBox.SelectedIndex
    if ($index -lt 0) { $index = 0 }
    $Profiles[$index]
}

function Get-CurrentRoutineState {
    foreach ($checkBox in @($RoutineStepsPanel.Children)) {
        [pscustomobject]@{
            Name = [string]$checkBox.Content
            Complete = [bool]$checkBox.IsChecked
        }
    }
}

function Update-RoutineProgress {
    $steps = @(Get-CurrentRoutineState)
    $complete = @($steps | Where-Object { $_.Complete }).Count
    $RoutineProgressText.Text = "$complete of $($steps.Count) complete"
    if ($steps.Count -gt 0 -and $complete -eq $steps.Count) {
        $RoutineProgressText.Text += ' - ready to queue'
        $RoutineProgressText.Foreground = '#9BE39F'
    } else {
        $RoutineProgressText.Foreground = '#B8C0C8'
    }
}

function Initialize-Routine {
    $RoutineStepsPanel.Children.Clear()
    $profile = Get-SelectedProfile
    $steps = @($profile.WarmupRoutine | Where-Object { $_ })
    if ($steps.Count -eq 0) {
        $steps = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
    }

    foreach ($step in $steps) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = [string]$step
        $checkBox.Foreground = '#F4F4F4'
        $checkBox.FontSize = 16
        $checkBox.Margin = '0,0,0,12'
        $checkBox.Add_Checked({ Update-RoutineProgress })
        $checkBox.Add_Unchecked({ Update-RoutineProgress })
        [void]$RoutineStepsPanel.Children.Add($checkBox)
    }
    Update-RoutineProgress
}

function Refresh-GuidedView {
    $profile = Get-SelectedProfile
    $script:LastProfileName = [string]$profile.DisplayName
    $audit = Invoke-GuidedAudit
    $cards = @(Convert-AuditToGuidedCards -Audit $audit -ProfileId $profile.Id)
    $queue = @(Get-RecommendedActionQueue -Cards $cards -ProfileId $profile.Id)
    $verdict = Get-ReadinessVerdict -Cards $cards

    $script:LastCards = $cards
    $script:LastQueue = $queue
    $script:LastVerdict = $verdict

    $ReadyCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Good' }).Count
    $ReviewCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Review' }).Count
    $FixCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Fix' }).Count
    $VerdictText.Text = "$verdict - $($profile.DisplayName)"

    $cardLines = foreach ($card in $cards) {
        "[$($card.Status)] $($card.Area)`r`n  What this means: $($card.Meaning)`r`n  What to do: $($card.Action)`r`n  Risk: $($card.Risk)`r`n  Backup/undo: $($card.UndoPath)`r`n"
    }
    Set-TextBoxLines -TextBox $CardsBox -Lines $cardLines

    $queueLines = foreach ($item in $queue) {
        "$($item.Action)`r`n  What it changes: $($item.WhatItChanges)`r`n  Why it matters: $($item.WhyItMatters)`r`n  Risk: $($item.Risk)`r`n  Backup/undo path: $($item.BackupUndoPath)`r`n  Reboot required: $($item.RequiresReboot)`r`n  Status: $($item.Status)`r`n"
    }
    Set-TextBoxLines -TextBox $QueueBox -Lines $queueLines

    $detailLines = @(
        "Profile: $($profile.Id)",
        "Audit generated: $($audit.GeneratedAt)",
        '',
        'Raw card evidence:'
    )
    foreach ($card in $cards) {
        $detailLines += "[$($card.Area)] $($card.Details)"
    }
    Set-TextBoxLines -TextBox $DetailsBox -Lines $detailLines
}

$Window.FindName('AuditBtn').Add_Click({
    try {
        Refresh-GuidedView
    } catch {
        $VerdictText.Text = 'Audit failed before readiness could be calculated.'
        $CardsBox.Text = $_.Exception.Message
    }
})

$Window.FindName('ReportBtn').Add_Click({
    try {
        if ($script:LastCards.Count -eq 0) { Refresh-GuidedView }
        $path = Write-GuidedReport -Cards $script:LastCards -Queue $script:LastQueue -Verdict $script:LastVerdict -ProfileName $script:LastProfileName -RoutineSteps @(Get-CurrentRoutineState) -SessionFocus $SessionFocusBox.Text
        [System.Windows.MessageBox]::Show("Report saved:`r`n$path", 'GPTOPT Guided Control Center') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Guided Control Center') | Out-Null
    }
})

$Window.FindName('AdvancedBtn').Add_Click({
    $entry = if (Test-Path -LiteralPath $AdvancedControlCenter) { $AdvancedControlCenter } else { $LegacyControlCenter }
    if (Test-Path -LiteralPath $entry) {
        Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$entry`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show('Advanced Control Center entry was not found.', 'GPTOPT Guided Control Center') | Out-Null
    }
})

$DetailsToggle.Add_Checked({ $DetailsBox.Visibility = 'Visible' })
$DetailsToggle.Add_Unchecked({ $DetailsBox.Visibility = 'Collapsed' })
$Window.FindName('ResetRoutineBtn').Add_Click({ Initialize-Routine; $SessionFocusBox.Clear() })
$ProfileBox.Add_SelectionChanged({
    if ($ProfileBox.SelectedIndex -ge 0) {
        Initialize-Routine
        Refresh-GuidedView
    }
})

Initialize-Routine
Refresh-GuidedView
$Window.ShowDialog() | Out-Null


    [pscustomobject]@{
        Found = $true
        Ready = ($hasCap -and $detectLevelTwo)
        Detail = "Profile=$path; FramerateLimit240=$hasCap; ApplicationDetectionLevel2=$detectLevelTwo"
    }
}

function New-Card {
    param(
        [string]$Area,
        [ValidateSet('Good', 'Review', 'Fix')]
        [string]$Status,
        [string]$Meaning,
        [string]$Action,
        [string]$Risk,
        [string]$UndoPath,
        [string]$Details
    )

    [pscustomobject]@{
        Area = $Area
        Status = $Status
        Meaning = $Meaning
        Action = $Action
        Risk = $Risk
        UndoPath = $UndoPath
        Details = $Details
    }
}

function Convert-AuditToGuidedCards {
    param(
        [object]$Audit,
        [string]$ProfileId
    )

    $cards = New-Object System.Collections.Generic.List[object]
    $checks = @($Audit.Checks)

    $pending = $checks | Where-Object { $_.Id -eq 'pending-reboot' } | Select-Object -First 1
    if ($pending -and $pending.RequiresReboot) {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'Windows Update or servicing is waiting for a reboot. Finish it before controlled benchmarks or ranked play.' -Action 'Restart before the next controlled gaming test.' -Risk 'Low. This completes an existing Windows servicing change.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } elseif ($pending -and $pending.Evidence -match 'Classification=Cleanup') {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'App or driver cleanup file is waiting for reboot. This is usually not a Windows servicing problem.' -Action 'Reboot later if this persists, or after installing drivers/updates.' -Risk 'Low. This does not block play by itself.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } else {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Good' -Meaning 'No pending reboot markers were detected.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details ($pending.Evidence)))
    }

    $windows = @($checks | Where-Object { $_.Id -in @('hags', 'mpo', 'game-mode', 'game-dvr') })
    $windowsReady = (
        ($windows | Where-Object { $_.Id -eq 'hags' }).Status -eq 'HwSchMode=2' -and
        ($windows | Where-Object { $_.Id -eq 'mpo' }).Status -eq 'OverlayTestMode=5' -and
        ($windows | Where-Object { $_.Id -eq 'game-mode' }).Status -eq 'AutoGameModeEnabled=1' -and
        ($windows | Where-Object { $_.Id -eq 'game-dvr' }).Status -eq 'GameDVR_Enabled=0'
    )
    if ($windowsReady) {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Good' -Meaning 'Windows graphics, Game Mode, and capture settings match the gaming baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    } else {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Review' -Meaning 'One or more Windows gaming settings are outside the selected baseline or could not be read.' -Action 'Review details before considering a backed-up change.' -Risk 'Medium-low if changed later; this audit is read-only.' -UndoPath 'Future write actions must export the affected registry keys first.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    }

    $rtssState = Test-RTSS240Baseline
    if ($ProfileId -eq 'halo.infinite') {
        if ($rtssState.Ready) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Good' -Meaning 'Halo is already set up for the RTSS 240 FPS baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details $rtssState.Detail))
        } elseif ($rtssState.Found) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'RTSS has a Halo profile, but it does not clearly match the 240 FPS baseline.' -Action 'Review the recommended queue item before changing the RTSS profile.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Restore the backed-up HaloInfinite.exe.cfg profile.' -Details $rtssState.Detail))
        } else {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'GPTOPT did not find a Halo-specific RTSS profile. The app can still run, but the 240 FPS limiter baseline is not confirmed.' -Action 'Install/start RTSS or create the Halo RTSS profile only if you use RTSS as the limiter.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Remove the generated RTSS profile or restore its backup.' -Details $rtssState.Detail))
        }
    } else {
        $cards.Add((New-Card -Area 'FPS Limiter' -Status 'Review' -Meaning 'This profile does not have a dedicated limiter rule yet.' -Action 'Use the game-specific limiter policy before stacking RTSS, in-game, or driver caps.' -Risk 'Low for review. Actual limiter changes must be backed up or documented.' -UndoPath 'Revert the limiter profile that was changed.' -Details 'Generic profile selected. No game-specific RTSS profile was inspected.'))
    }

    $haloSettings = Get-HaloSettingsPath
    if ($ProfileId -eq 'halo.infinite') {
        if (Test-Path -LiteralPath $haloSettings) {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were found. Guided Mode does not edit them during audit.' -Action 'Use the recommended queue only after reading backup and undo details.' -Risk 'Low if applied later with SpecControlSettings.json backup.' -UndoPath 'Restore the backed-up SpecControlSettings.json file.' -Details "Path=$haloSettings"))
        } else {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were not found. This is expected if Halo has not been installed or launched on this Windows profile.' -Action 'No fix required unless you are preparing a Halo session.' -Risk 'None.' -UndoPath 'Not required.' -Details "Missing path=$haloSettings"))
        }
    }

    $sonar = Get-SonarState
    if ($sonar.Available) {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Good' -Meaning 'SteelSeries Sonar is available through its app process or virtual audio device.' -Action 'No action needed unless routing sounds wrong.' -Risk 'None.' -UndoPath 'Not required.' -Details $sonar.Detail))
    } else {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Review' -Meaning 'Sonar was not detected as a running app or virtual audio device. This is fine if you do not use Sonar.' -Action 'Open SteelSeries GG only if Sonar is part of this profile.' -Risk 'Low.' -UndoPath 'Close SteelSeries GG.' -Details $sonar.Detail))
    }

    $tools = @(
        "RTSS running=$(Test-ProcessRunning -Name 'RTSS')",
        "MSI Afterburner running=$(Test-ProcessRunning -Name 'MSIAfterburner')",
        "Flydigi app running=$(Test-ProcessRunning -Name 'FlydigiSpaceStation')",
        "CapFrameX available=$(Test-CommandAvailable -Name 'CapFrameX.exe')",
        "PresentMon available=$(Test-CommandAvailable -Name 'PresentMon.exe')"
    )
    $cards.Add((New-Card -Area 'Optional Session Tools' -Status 'Good' -Meaning 'Optional tools were checked without treating missing apps as a readiness failure.' -Action 'Open only the tools you intentionally use for this session.' -Risk 'Low.' -UndoPath 'Close the app you opened.' -Details ($tools -join "`r`n")))

    return @($cards.ToArray())
}

function New-ActionItem {
    param(
        [string]$Name,
        [string]$WhatChanges,
        [string]$WhyItMatters,
        [string]$Risk,
        [string]$BackupUndo,
        [bool]$RequiresReboot
    )

    [pscustomobject]@{
        Action = $Name
        WhatItChanges = $WhatChanges
        WhyItMatters = $WhyItMatters
        Risk = $Risk
        BackupUndoPath = $BackupUndo
        RequiresReboot = if ($RequiresReboot) { 'Yes' } else { 'No' }
        Status = 'Preview only. Not applied from Guided Mode.'
    }
}

function Get-RecommendedActionQueue {
    param(
        [object[]]$Cards,
        [string]$ProfileId
    )

    $items = New-Object System.Collections.Generic.List[object]
    if (@($Cards | Where-Object { $_.Area -eq 'Windows Reboot State' -and $_.Details -match 'Classification=Servicing' }).Count -gt 0) {
        $items.Add((New-ActionItem -Name 'Finish Pending Reboot' -WhatChanges 'Nothing inside GPTOPT. You decide when to reboot Windows.' -WhyItMatters 'A pending reboot can make benchmark results and driver state inconsistent.' -Risk 'Low' -BackupUndo 'No GPTOPT backup required because GPTOPT does not start the reboot.' -RequiresReboot $true))
    }

    $items.Add((New-ActionItem -Name 'Save Readiness Report' -WhatChanges 'Writes a Markdown readiness summary under the repo Reports folder.' -WhyItMatters 'Gives you a before/after record without changing Windows, Halo, or tool settings.' -Risk 'Low' -BackupUndo 'Delete the generated report if you do not need it.' -RequiresReboot $false))

    if ($ProfileId -eq 'halo.infinite') {
        $items.Add((New-ActionItem -Name 'Apply RTSS Halo 240 Cap' -WhatChanges 'Would update only the Halo RTSS profile to use a 240 FPS cap and enabled detection.' -WhyItMatters 'Keeps the FPS limiter consistent with the current competitive baseline.' -Risk 'Low' -BackupUndo 'Back up HaloInfinite.exe.cfg first; undo by restoring that file.' -RequiresReboot $false))
        $items.Add((New-ActionItem -Name 'Apply Halo Display Baseline' -WhatChanges 'Would change only listed Halo display/session fields in SpecControlSettings.json.' -WhyItMatters 'Keeps Halo display behavior aligned with the selected competitive profile.' -Risk 'Low' -BackupUndo 'Back up SpecControlSettings.json first; undo by restoring that backup.' -RequiresReboot $false))
    }

    $items.Add((New-ActionItem -Name 'Open Session Apps' -WhatChanges 'Starts existing tools such as RTSS, Sonar, or controller software only when you choose them.' -WhyItMatters 'Confirms the same app stack is active before you judge game feel.' -Risk 'Low' -BackupUndo 'Close the app or disable its own startup option.' -RequiresReboot $false))

    return @($items.ToArray())
}

function Get-ReadinessVerdict {
    param([object[]]$Cards)

    if (@($Cards | Where-Object { $_.Status -eq 'Fix' }).Count -gt 0) { return 'Fix First' }
    if (@($Cards | Where-Object { $_.Status -eq 'Review' }).Count -gt 0) { return 'Ready with Review Items' }
    return 'Ready to Play'
}

function Write-GuidedReport {
    param(
        [object[]]$Cards,
        [object[]]$Queue,
        [string]$Verdict,
        [string]$ProfileName,
        [object[]]$RoutineSteps = @(),
        [string]$SessionFocus = ''
    )

    $path = Join-Path $ReportsDir ("GPTOPT-GuidedReadiness_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $lines = @(
        '# GPTOPT Guided Readiness',
        '',
        "- Generated: $((Get-Date).ToString('o'))",
        "- Profile: $ProfileName",
        "- Verdict: $Verdict",
        '',
        '## Readiness Cards'
    )
    foreach ($card in $Cards) {
        $explanation = Get-CardExplanation -Area $card.Area
        $lines += "- $($explanation.label)"
        $lines += "  - Current status: $($card.Status)"
        $lines += "  - Summary: $($card.Meaning)"
        $lines += "  - Why it matters: $($explanation.whyItMatters)"
        $lines += "  - Good state: $($explanation.goodState)"
        $lines += "  - Safe action: $($card.Action)"
        $lines += "  - Risk: $($card.Risk)"
        $lines += "  - Undo path: $($card.UndoPath)"
    }
    $lines += ''
    $lines += '## Recommended Action Queue'
    foreach ($item in $Queue) {
        $lines += "- $($item.Action): changes=$($item.WhatItChanges); why=$($item.WhyItMatters); risk=$($item.Risk); undo=$($item.BackupUndoPath); reboot=$($item.RequiresReboot); status=$($item.Status)"
    }
    $lines += ''
    $lines += '## Pre-Game Routine'
    foreach ($step in $RoutineSteps) {
        $mark = if ($step.Complete) { 'x' } else { ' ' }
        $lines += "- [$mark] $($step.Name)"
    }
    if ($SessionFocus.Trim()) {
        $lines += ''
        $lines += "Session focus: $($SessionFocus.Trim())"
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Set-TextBoxLines {
    param(
        [object]$TextBox,
        [string[]]$Lines
    )

    $TextBox.Text = ($Lines -join "`r`n")
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="GPTOPT Guided Control Center" Height="760" Width="1040" WindowStartupLocation="CenterScreen" Background="#101214">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" LastChildFill="True">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
        <Button Name="AdvancedBtn" Content="Advanced Control Center" Width="190" Height="36" Margin="8,0,0,0"/>
        <Button Name="ReportBtn" Content="Save Report" Width="120" Height="36" Margin="8,0,0,0"/>
      </StackPanel>
      <StackPanel>
        <TextBlock Text="GPTOPT Guided Control Center" FontSize="28" FontWeight="Bold" Foreground="#F4F4F4"/>
        <TextBlock Text="Plain-language readiness for competitive PC gaming. Audit and preview only." Foreground="#B8C0C8" Margin="0,4,0,0"/>
      </StackPanel>
    </DockPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,16,0,12">
      <TextBlock Text="Game Profile" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <ComboBox Name="ProfileBox" Width="260" Height="32"/>
      <Button Name="AuditBtn" Content="Run Audit" Width="120" Height="34" Margin="12,0,0,0"/>
      <CheckBox Name="DetailsToggle" Content="Show Details" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="18,0,0,0"/>
    </StackPanel>
    <TabControl Grid.Row="2" Name="MainTabs" Background="#101214" Foreground="#F4F4F4">
      <TabItem Header="Readiness">
       <Grid Margin="8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Margin="0,0,12,0">
        <UniformGrid Columns="3" Margin="0,0,0,12">
          <Border Name="ReadyCard" BorderBrush="#2E7D32" BorderThickness="1" Background="#172019" Padding="12" Margin="0,0,8,0">
            <StackPanel><TextBlock Text="Ready to Play" FontWeight="Bold" Foreground="#DDF5DE"/><TextBlock Name="ReadyCount" Text="0" FontSize="28" Foreground="#DDF5DE"/></StackPanel>
          </Border>
          <Border Name="ReviewCard" BorderBrush="#B8860B" BorderThickness="1" Background="#211D12" Padding="12" Margin="4,0,4,0">
            <StackPanel><TextBlock Text="Ready with Review Items" FontWeight="Bold" Foreground="#FFE6A3"/><TextBlock Name="ReviewCount" Text="0" FontSize="28" Foreground="#FFE6A3"/></StackPanel>
          </Border>
          <Border Name="FixCard" BorderBrush="#B23B3B" BorderThickness="1" Background="#241515" Padding="12" Margin="8,0,0,0">
            <StackPanel><TextBlock Text="Fix First" FontWeight="Bold" Foreground="#FFD5D5"/><TextBlock Name="FixCount" Text="0" FontSize="28" Foreground="#FFD5D5"/></StackPanel>
          </Border>
        </UniformGrid>
        <TextBlock Name="VerdictText" Text="Run an audit to check readiness." FontSize="20" FontWeight="Bold" Foreground="#F4F4F4" Margin="0,0,0,8"/>
        <TextBox Name="CardsBox" Height="410" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <TextBlock Text="Recommended Action Queue" FontSize="18" FontWeight="Bold" Foreground="#F4F4F4"/>
          <TextBox Name="QueueBox" Height="500" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
        </StackPanel>
       </Grid>
      </TabItem>
      <TabItem Header="Pre-Game Routine">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" LastChildFill="True">
            <Button Name="ResetRoutineBtn" DockPanel.Dock="Right" Content="Reset" Width="90" Height="32" Margin="8,0,0,0"/>
            <StackPanel>
              <TextBlock Text="Pre-Game Routine" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBlock Name="RoutineProgressText" Text="0 of 0 complete" Foreground="#B8C0C8" Margin="0,4,0,0"/>
            </StackPanel>
          </DockPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,14,0,14">
            <StackPanel Name="RoutineStepsPanel"/>
          </ScrollViewer>
          <StackPanel Grid.Row="2">
            <TextBlock Text="Session Focus" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBox Name="SessionFocusBox" Height="56" TextWrapping="Wrap" AcceptsReturn="True" Background="#080A0C" Foreground="#ECEFF1" Margin="0,6,0,0" ToolTip="One specific thing to focus on this session."/>
          </StackPanel>
        </Grid>
      </TabItem>
    </TabControl>
    <DockPanel Grid.Row="3" Margin="0,12,0,0">
      <TextBlock DockPanel.Dock="Top" Text="Details" FontWeight="Bold" Foreground="#F4F4F4"/>
      <TextBox Name="DetailsBox" Visibility="Collapsed" IsReadOnly="True" TextWrapping="NoWrap" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#C9D1D9" FontFamily="Consolas"/>
    </DockPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$ProfileBox = $Window.FindName('ProfileBox')
$ReadyCount = $Window.FindName('ReadyCount')
$ReviewCount = $Window.FindName('ReviewCount')
$FixCount = $Window.FindName('FixCount')
$VerdictText = $Window.FindName('VerdictText')
$CardsBox = $Window.FindName('CardsBox')
$QueueBox = $Window.FindName('QueueBox')
$DetailsBox = $Window.FindName('DetailsBox')
$DetailsToggle = $Window.FindName('DetailsToggle')
$RoutineStepsPanel = $Window.FindName('RoutineStepsPanel')
$RoutineProgressText = $Window.FindName('RoutineProgressText')
$SessionFocusBox = $Window.FindName('SessionFocusBox')

$Profiles = @(Get-GuidedProfiles)
foreach ($profile in $Profiles) {
    [void]$ProfileBox.Items.Add($profile.DisplayName)
}
$ProfileBox.SelectedIndex = 0

$script:LastCards = @()
$script:LastQueue = @()
$script:LastVerdict = 'Not audited'
$script:LastProfileName = [string]$Profiles[0].DisplayName

function Get-SelectedProfile {
    $index = $ProfileBox.SelectedIndex
    if ($index -lt 0) { $index = 0 }
    $Profiles[$index]
}

function Get-CurrentRoutineState {
    foreach ($checkBox in @($RoutineStepsPanel.Children)) {
        [pscustomobject]@{
            Name = [string]$checkBox.Content
            Complete = [bool]$checkBox.IsChecked
        }
    }
}

function Update-RoutineProgress {
    $steps = @(Get-CurrentRoutineState)
    $complete = @($steps | Where-Object { $_.Complete }).Count
    $RoutineProgressText.Text = "$complete of $($steps.Count) complete"
    if ($steps.Count -gt 0 -and $complete -eq $steps.Count) {
        $RoutineProgressText.Text += ' - ready to queue'
        $RoutineProgressText.Foreground = '#9BE39F'
    } else {
        $RoutineProgressText.Foreground = '#B8C0C8'
    }
}

function Initialize-Routine {
    $RoutineStepsPanel.Children.Clear()
    $profile = Get-SelectedProfile
    $steps = @($profile.WarmupRoutine | Where-Object { $_ })
    if ($steps.Count -eq 0) {
        $steps = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
    }

    foreach ($step in $steps) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = [string]$step
        $checkBox.Foreground = '#F4F4F4'
        $checkBox.FontSize = 16
        $checkBox.Margin = '0,0,0,12'
        $checkBox.Add_Checked({ Update-RoutineProgress })
        $checkBox.Add_Unchecked({ Update-RoutineProgress })
        [void]$RoutineStepsPanel.Children.Add($checkBox)
    }
    Update-RoutineProgress
}

function Refresh-GuidedView {
    $profile = Get-SelectedProfile
    $script:LastProfileName = [string]$profile.DisplayName
    $audit = Invoke-GuidedAudit
    $cards = @(Convert-AuditToGuidedCards -Audit $audit -ProfileId $profile.Id)
    $queue = @(Get-RecommendedActionQueue -Cards $cards -ProfileId $profile.Id)
    $verdict = Get-ReadinessVerdict -Cards $cards

    $script:LastCards = $cards
    $script:LastQueue = $queue
    $script:LastVerdict = $verdict

    $ReadyCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Good' }).Count
    $ReviewCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Review' }).Count
    $FixCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Fix' }).Count
    $VerdictText.Text = "$verdict - $($profile.DisplayName)"

    $cardLines = foreach ($card in $cards) {
        $explanation = Get-CardExplanation -Area $card.Area
        "$($explanation.label)`r`n  Current status: $($card.Status)`r`n  Summary: $($card.Meaning)`r`n  Why it matters: $($explanation.whyItMatters)`r`n  Good state: $($explanation.goodState)`r`n  Safe action: $($card.Action)`r`n  Risk: $($card.Risk)`r`n  Undo path: $($card.UndoPath)`r`n"
    }
    Set-TextBoxLines -TextBox $CardsBox -Lines $cardLines

    $queueLines = foreach ($item in $queue) {
        "$($item.Action)`r`n  What it changes: $($item.WhatItChanges)`r`n  Why it matters: $($item.WhyItMatters)`r`n  Risk: $($item.Risk)`r`n  Backup/undo path: $($item.BackupUndoPath)`r`n  Reboot required: $($item.RequiresReboot)`r`n  Status: $($item.Status)`r`n"
    }
    Set-TextBoxLines -TextBox $QueueBox -Lines $queueLines

    $detailLines = @(
        "Profile: $($profile.Id)",
        "Audit generated: $($audit.GeneratedAt)",
        '',
        'Raw card evidence:'
    )
    foreach ($card in $cards) {
        $detailLines += "[$($card.Area)] $($card.Details)"
    }
    Set-TextBoxLines -TextBox $DetailsBox -Lines $detailLines
}

$Window.FindName('AuditBtn').Add_Click({
    try {
        Refresh-GuidedView
    } catch {
        $VerdictText.Text = 'Audit failed before readiness could be calculated.'
        $CardsBox.Text = $_.Exception.Message
    }
})

$Window.FindName('ReportBtn').Add_Click({
    try {
        if ($script:LastCards.Count -eq 0) { Refresh-GuidedView }
        $path = Write-GuidedReport -Cards $script:LastCards -Queue $script:LastQueue -Verdict $script:LastVerdict -ProfileName $script:LastProfileName -RoutineSteps @(Get-CurrentRoutineState) -SessionFocus $SessionFocusBox.Text
        [System.Windows.MessageBox]::Show("Report saved:`r`n$path", 'GPTOPT Guided Control Center') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Guided Control Center') | Out-Null
    }
})

$Window.FindName('AdvancedBtn').Add_Click({
    $entry = if (Test-Path -LiteralPath $AdvancedControlCenter) { $AdvancedControlCenter } else { $LegacyControlCenter }
    if (Test-Path -LiteralPath $entry) {
        Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$entry`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show('Advanced Control Center entry was not found.', 'GPTOPT Guided Control Center') | Out-Null
    }
})

$DetailsToggle.Add_Checked({ $DetailsBox.Visibility = 'Visible' })
$DetailsToggle.Add_Unchecked({ $DetailsBox.Visibility = 'Collapsed' })
$Window.FindName('ResetRoutineBtn').Add_Click({ Initialize-Routine; $SessionFocusBox.Clear() })
$ProfileBox.Add_SelectionChanged({
    if ($ProfileBox.SelectedIndex -ge 0) {
        Initialize-Routine
        Refresh-GuidedView
    }
})

Initialize-Routine
Refresh-GuidedView
$Window.ShowDialog() | Out-Null


    [pscustomobject]@{
        Found = $true
        Ready = ($hasCap -and $detectLevelTwo)
        Detail = "Profile=$path; FramerateLimit240=$hasCap; ApplicationDetectionLevel2=$detectLevelTwo"
    }
}

function New-Card {
    param(
        [string]$Area,
        [ValidateSet('Good', 'Review', 'Fix')]
        [string]$Status,
        [string]$Meaning,
        [string]$Action,
        [string]$Risk,
        [string]$UndoPath,
        [string]$Details
    )

    [pscustomobject]@{
        Area = $Area
        Status = $Status
        Meaning = $Meaning
        Action = $Action
        Risk = $Risk
        UndoPath = $UndoPath
        Details = $Details
    }
}

function Convert-AuditToGuidedCards {
    param(
        [object]$Audit,
        [string]$ProfileId
    )

    $cards = New-Object System.Collections.Generic.List[object]
    $checks = @($Audit.Checks)

    $pending = $checks | Where-Object { $_.Id -eq 'pending-reboot' } | Select-Object -First 1
    if ($pending -and $pending.RequiresReboot) {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'Windows Update or servicing is waiting for a reboot. Finish it before controlled benchmarks or ranked play.' -Action 'Restart before the next controlled gaming test.' -Risk 'Low. This completes an existing Windows servicing change.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } elseif ($pending -and $pending.Evidence -match 'Classification=Cleanup') {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Review' -Meaning 'App or driver cleanup file is waiting for reboot. This is usually not a Windows servicing problem.' -Action 'Reboot later if this persists, or after installing drivers/updates.' -Risk 'Low. This does not block play by itself.' -UndoPath 'Not required. GPTOPT does not trigger the reboot.' -Details $pending.Evidence))
    } else {
        $cards.Add((New-Card -Area 'Windows Reboot State' -Status 'Good' -Meaning 'No pending reboot markers were detected.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details ($pending.Evidence)))
    }

    $windows = @($checks | Where-Object { $_.Id -in @('hags', 'mpo', 'game-mode', 'game-dvr') })
    $windowsReady = (
        ($windows | Where-Object { $_.Id -eq 'hags' }).Status -eq 'HwSchMode=2' -and
        ($windows | Where-Object { $_.Id -eq 'mpo' }).Status -eq 'OverlayTestMode=5' -and
        ($windows | Where-Object { $_.Id -eq 'game-mode' }).Status -eq 'AutoGameModeEnabled=1' -and
        ($windows | Where-Object { $_.Id -eq 'game-dvr' }).Status -eq 'GameDVR_Enabled=0'
    )
    if ($windowsReady) {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Good' -Meaning 'Windows graphics, Game Mode, and capture settings match the gaming baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    } else {
        $cards.Add((New-Card -Area 'Windows Gaming Settings' -Status 'Review' -Meaning 'One or more Windows gaming settings are outside the selected baseline or could not be read.' -Action 'Review details before considering a backed-up change.' -Risk 'Medium-low if changed later; this audit is read-only.' -UndoPath 'Future write actions must export the affected registry keys first.' -Details (($windows | ForEach-Object { "$($_.Name): $($_.Evidence)" }) -join "`r`n")))
    }

    $rtssState = Test-RTSS240Baseline
    if ($ProfileId -eq 'halo.infinite') {
        if ($rtssState.Ready) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Good' -Meaning 'Halo is already set up for the RTSS 240 FPS baseline.' -Action 'No action needed.' -Risk 'None.' -UndoPath 'Not required.' -Details $rtssState.Detail))
        } elseif ($rtssState.Found) {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'RTSS has a Halo profile, but it does not clearly match the 240 FPS baseline.' -Action 'Review the recommended queue item before changing the RTSS profile.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Restore the backed-up HaloInfinite.exe.cfg profile.' -Details $rtssState.Detail))
        } else {
            $cards.Add((New-Card -Area 'RTSS FPS Cap' -Status 'Review' -Meaning 'GPTOPT did not find a Halo-specific RTSS profile. The app can still run, but the 240 FPS limiter baseline is not confirmed.' -Action 'Install/start RTSS or create the Halo RTSS profile only if you use RTSS as the limiter.' -Risk 'Low if applied later with a profile backup.' -UndoPath 'Remove the generated RTSS profile or restore its backup.' -Details $rtssState.Detail))
        }
    } else {
        $cards.Add((New-Card -Area 'FPS Limiter' -Status 'Review' -Meaning 'This profile does not have a dedicated limiter rule yet.' -Action 'Use the game-specific limiter policy before stacking RTSS, in-game, or driver caps.' -Risk 'Low for review. Actual limiter changes must be backed up or documented.' -UndoPath 'Revert the limiter profile that was changed.' -Details 'Generic profile selected. No game-specific RTSS profile was inspected.'))
    }

    $haloSettings = Get-HaloSettingsPath
    if ($ProfileId -eq 'halo.infinite') {
        if (Test-Path -LiteralPath $haloSettings) {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were found. Guided Mode does not edit them during audit.' -Action 'Use the recommended queue only after reading backup and undo details.' -Risk 'Low if applied later with SpecControlSettings.json backup.' -UndoPath 'Restore the backed-up SpecControlSettings.json file.' -Details "Path=$haloSettings"))
        } else {
            $cards.Add((New-Card -Area 'Halo Display Settings' -Status 'Review' -Meaning 'Halo settings were not found. This is expected if Halo has not been installed or launched on this Windows profile.' -Action 'No fix required unless you are preparing a Halo session.' -Risk 'None.' -UndoPath 'Not required.' -Details "Missing path=$haloSettings"))
        }
    }

    $sonar = Get-SonarState
    if ($sonar.Available) {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Good' -Meaning 'SteelSeries Sonar is available through its app process or virtual audio device.' -Action 'No action needed unless routing sounds wrong.' -Risk 'None.' -UndoPath 'Not required.' -Details $sonar.Detail))
    } else {
        $cards.Add((New-Card -Area 'Audio Routing' -Status 'Review' -Meaning 'Sonar was not detected as a running app or virtual audio device. This is fine if you do not use Sonar.' -Action 'Open SteelSeries GG only if Sonar is part of this profile.' -Risk 'Low.' -UndoPath 'Close SteelSeries GG.' -Details $sonar.Detail))
    }

    $tools = @(
        "RTSS running=$(Test-ProcessRunning -Name 'RTSS')",
        "MSI Afterburner running=$(Test-ProcessRunning -Name 'MSIAfterburner')",
        "Flydigi app running=$(Test-ProcessRunning -Name 'FlydigiSpaceStation')",
        "CapFrameX available=$(Test-CommandAvailable -Name 'CapFrameX.exe')",
        "PresentMon available=$(Test-CommandAvailable -Name 'PresentMon.exe')"
    )
    $cards.Add((New-Card -Area 'Optional Session Tools' -Status 'Good' -Meaning 'Optional tools were checked without treating missing apps as a readiness failure.' -Action 'Open only the tools you intentionally use for this session.' -Risk 'Low.' -UndoPath 'Close the app you opened.' -Details ($tools -join "`r`n")))

    return @($cards.ToArray())
}

function New-ActionItem {
    param(
        [string]$Name,
        [string]$WhatChanges,
        [string]$WhyItMatters,
        [string]$Risk,
        [string]$BackupUndo,
        [bool]$RequiresReboot
    )

    [pscustomobject]@{
        Action = $Name
        WhatItChanges = $WhatChanges
        WhyItMatters = $WhyItMatters
        Risk = $Risk
        BackupUndoPath = $BackupUndo
        RequiresReboot = if ($RequiresReboot) { 'Yes' } else { 'No' }
        Status = 'Preview only. Not applied from Guided Mode.'
    }
}

function Get-RecommendedActionQueue {
    param(
        [object[]]$Cards,
        [string]$ProfileId
    )

    $items = New-Object System.Collections.Generic.List[object]
    if (@($Cards | Where-Object { $_.Area -eq 'Windows Reboot State' -and $_.Details -match 'Classification=Servicing' }).Count -gt 0) {
        $items.Add((New-ActionItem -Name 'Finish Pending Reboot' -WhatChanges 'Nothing inside GPTOPT. You decide when to reboot Windows.' -WhyItMatters 'A pending reboot can make benchmark results and driver state inconsistent.' -Risk 'Low' -BackupUndo 'No GPTOPT backup required because GPTOPT does not start the reboot.' -RequiresReboot $true))
    }

    $items.Add((New-ActionItem -Name 'Save Readiness Report' -WhatChanges 'Writes a Markdown readiness summary under the repo Reports folder.' -WhyItMatters 'Gives you a before/after record without changing Windows, Halo, or tool settings.' -Risk 'Low' -BackupUndo 'Delete the generated report if you do not need it.' -RequiresReboot $false))

    if ($ProfileId -eq 'halo.infinite') {
        $items.Add((New-ActionItem -Name 'Apply RTSS Halo 240 Cap' -WhatChanges 'Would update only the Halo RTSS profile to use a 240 FPS cap and enabled detection.' -WhyItMatters 'Keeps the FPS limiter consistent with the current competitive baseline.' -Risk 'Low' -BackupUndo 'Back up HaloInfinite.exe.cfg first; undo by restoring that file.' -RequiresReboot $false))
        $items.Add((New-ActionItem -Name 'Apply Halo Display Baseline' -WhatChanges 'Would change only listed Halo display/session fields in SpecControlSettings.json.' -WhyItMatters 'Keeps Halo display behavior aligned with the selected competitive profile.' -Risk 'Low' -BackupUndo 'Back up SpecControlSettings.json first; undo by restoring that backup.' -RequiresReboot $false))
    }

    $items.Add((New-ActionItem -Name 'Open Session Apps' -WhatChanges 'Starts existing tools such as RTSS, Sonar, or controller software only when you choose them.' -WhyItMatters 'Confirms the same app stack is active before you judge game feel.' -Risk 'Low' -BackupUndo 'Close the app or disable its own startup option.' -RequiresReboot $false))

    return @($items.ToArray())
}

function Get-ReadinessVerdict {
    param([object[]]$Cards)

    if (@($Cards | Where-Object { $_.Status -eq 'Fix' }).Count -gt 0) { return 'Fix First' }
    if (@($Cards | Where-Object { $_.Status -eq 'Review' }).Count -gt 0) { return 'Ready with Review Items' }
    return 'Ready to Play'
}

function Write-GuidedReport {
    param(
        [object[]]$Cards,
        [object[]]$Queue,
        [string]$Verdict,
        [string]$ProfileName,
        [object[]]$RoutineSteps = @(),
        [string]$SessionFocus = ''
    )

    $path = Join-Path $ReportsDir ("GPTOPT-GuidedReadiness_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $lines = @(
        '# GPTOPT Guided Readiness',
        '',
        "- Generated: $((Get-Date).ToString('o'))",
        "- Profile: $ProfileName",
        "- Verdict: $Verdict",
        '',
        '## Readiness Cards'
    )
    foreach ($card in $Cards) {
        $lines += "- [$($card.Status)] $($card.Area): $($card.Meaning) Action: $($card.Action)"
    }
    $lines += ''
    $lines += '## Recommended Action Queue'
    foreach ($item in $Queue) {
        $lines += "- $($item.Action): changes=$($item.WhatItChanges); why=$($item.WhyItMatters); risk=$($item.Risk); undo=$($item.BackupUndoPath); reboot=$($item.RequiresReboot); status=$($item.Status)"
    }
    $lines += ''
    $lines += '## Pre-Game Routine'
    foreach ($step in $RoutineSteps) {
        $mark = if ($step.Complete) { 'x' } else { ' ' }
        $lines += "- [$mark] $($step.Name)"
    }
    if ($SessionFocus.Trim()) {
        $lines += ''
        $lines += "Session focus: $($SessionFocus.Trim())"
    }
    $lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Set-TextBoxLines {
    param(
        [object]$TextBox,
        [string[]]$Lines
    )

    $TextBox.Text = ($Lines -join "`r`n")
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="GPTOPT Guided Control Center" Height="760" Width="1040" WindowStartupLocation="CenterScreen" Background="#101214">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" LastChildFill="True">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
        <Button Name="AdvancedBtn" Content="Advanced Control Center" Width="190" Height="36" Margin="8,0,0,0"/>
        <Button Name="ReportBtn" Content="Save Report" Width="120" Height="36" Margin="8,0,0,0"/>
      </StackPanel>
      <StackPanel>
        <TextBlock Text="GPTOPT Guided Control Center" FontSize="28" FontWeight="Bold" Foreground="#F4F4F4"/>
        <TextBlock Text="Plain-language readiness for competitive PC gaming. Audit and preview only." Foreground="#B8C0C8" Margin="0,4,0,0"/>
      </StackPanel>
    </DockPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,16,0,12">
      <TextBlock Text="Game Profile" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <ComboBox Name="ProfileBox" Width="260" Height="32"/>
      <Button Name="AuditBtn" Content="Run Audit" Width="120" Height="34" Margin="12,0,0,0"/>
      <CheckBox Name="DetailsToggle" Content="Show Details" Foreground="#F4F4F4" VerticalAlignment="Center" Margin="18,0,0,0"/>
    </StackPanel>
    <TabControl Grid.Row="2" Name="MainTabs" Background="#101214" Foreground="#F4F4F4">
      <TabItem Header="Readiness">
       <Grid Margin="8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Margin="0,0,12,0">
        <UniformGrid Columns="3" Margin="0,0,0,12">
          <Border Name="ReadyCard" BorderBrush="#2E7D32" BorderThickness="1" Background="#172019" Padding="12" Margin="0,0,8,0">
            <StackPanel><TextBlock Text="Ready to Play" FontWeight="Bold" Foreground="#DDF5DE"/><TextBlock Name="ReadyCount" Text="0" FontSize="28" Foreground="#DDF5DE"/></StackPanel>
          </Border>
          <Border Name="ReviewCard" BorderBrush="#B8860B" BorderThickness="1" Background="#211D12" Padding="12" Margin="4,0,4,0">
            <StackPanel><TextBlock Text="Ready with Review Items" FontWeight="Bold" Foreground="#FFE6A3"/><TextBlock Name="ReviewCount" Text="0" FontSize="28" Foreground="#FFE6A3"/></StackPanel>
          </Border>
          <Border Name="FixCard" BorderBrush="#B23B3B" BorderThickness="1" Background="#241515" Padding="12" Margin="8,0,0,0">
            <StackPanel><TextBlock Text="Fix First" FontWeight="Bold" Foreground="#FFD5D5"/><TextBlock Name="FixCount" Text="0" FontSize="28" Foreground="#FFD5D5"/></StackPanel>
          </Border>
        </UniformGrid>
        <TextBlock Name="VerdictText" Text="Run an audit to check readiness." FontSize="20" FontWeight="Bold" Foreground="#F4F4F4" Margin="0,0,0,8"/>
        <TextBox Name="CardsBox" Height="410" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <TextBlock Text="Recommended Action Queue" FontSize="18" FontWeight="Bold" Foreground="#F4F4F4"/>
          <TextBox Name="QueueBox" Height="500" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
        </StackPanel>
       </Grid>
      </TabItem>
      <TabItem Header="Pre-Game Routine">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" LastChildFill="True">
            <Button Name="ResetRoutineBtn" DockPanel.Dock="Right" Content="Reset" Width="90" Height="32" Margin="8,0,0,0"/>
            <StackPanel>
              <TextBlock Text="Pre-Game Routine" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBlock Name="RoutineProgressText" Text="0 of 0 complete" Foreground="#B8C0C8" Margin="0,4,0,0"/>
            </StackPanel>
          </DockPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,14,0,14">
            <StackPanel Name="RoutineStepsPanel"/>
          </ScrollViewer>
          <StackPanel Grid.Row="2">
            <TextBlock Text="Session Focus" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBox Name="SessionFocusBox" Height="56" TextWrapping="Wrap" AcceptsReturn="True" Background="#080A0C" Foreground="#ECEFF1" Margin="0,6,0,0" ToolTip="One specific thing to focus on this session."/>
          </StackPanel>
        </Grid>
      </TabItem>
    </TabControl>
    <DockPanel Grid.Row="3" Margin="0,12,0,0">
      <TextBlock DockPanel.Dock="Top" Text="Details" FontWeight="Bold" Foreground="#F4F4F4"/>
      <TextBox Name="DetailsBox" Visibility="Collapsed" IsReadOnly="True" TextWrapping="NoWrap" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#C9D1D9" FontFamily="Consolas"/>
    </DockPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$ProfileBox = $Window.FindName('ProfileBox')
$ReadyCount = $Window.FindName('ReadyCount')
$ReviewCount = $Window.FindName('ReviewCount')
$FixCount = $Window.FindName('FixCount')
$VerdictText = $Window.FindName('VerdictText')
$CardsBox = $Window.FindName('CardsBox')
$QueueBox = $Window.FindName('QueueBox')
$DetailsBox = $Window.FindName('DetailsBox')
$DetailsToggle = $Window.FindName('DetailsToggle')
$RoutineStepsPanel = $Window.FindName('RoutineStepsPanel')
$RoutineProgressText = $Window.FindName('RoutineProgressText')
$SessionFocusBox = $Window.FindName('SessionFocusBox')

$Profiles = @(Get-GuidedProfiles)
foreach ($profile in $Profiles) {
    [void]$ProfileBox.Items.Add($profile.DisplayName)
}
$ProfileBox.SelectedIndex = 0

$script:LastCards = @()
$script:LastQueue = @()
$script:LastVerdict = 'Not audited'
$script:LastProfileName = [string]$Profiles[0].DisplayName

function Get-SelectedProfile {
    $index = $ProfileBox.SelectedIndex
    if ($index -lt 0) { $index = 0 }
    $Profiles[$index]
}

function Get-CurrentRoutineState {
    foreach ($checkBox in @($RoutineStepsPanel.Children)) {
        [pscustomobject]@{
            Name = [string]$checkBox.Content
            Complete = [bool]$checkBox.IsChecked
        }
    }
}

function Update-RoutineProgress {
    $steps = @(Get-CurrentRoutineState)
    $complete = @($steps | Where-Object { $_.Complete }).Count
    $RoutineProgressText.Text = "$complete of $($steps.Count) complete"
    if ($steps.Count -gt 0 -and $complete -eq $steps.Count) {
        $RoutineProgressText.Text += ' - ready to queue'
        $RoutineProgressText.Foreground = '#9BE39F'
    } else {
        $RoutineProgressText.Foreground = '#B8C0C8'
    }
}

function Initialize-Routine {
    $RoutineStepsPanel.Children.Clear()
    $profile = Get-SelectedProfile
    $steps = @($profile.WarmupRoutine | Where-Object { $_ })
    if ($steps.Count -eq 0) {
        $steps = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
    }

    foreach ($step in $steps) {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Content = [string]$step
        $checkBox.Foreground = '#F4F4F4'
        $checkBox.FontSize = 16
        $checkBox.Margin = '0,0,0,12'
        $checkBox.Add_Checked({ Update-RoutineProgress })
        $checkBox.Add_Unchecked({ Update-RoutineProgress })
        [void]$RoutineStepsPanel.Children.Add($checkBox)
    }
    Update-RoutineProgress
}

function Refresh-GuidedView {
    $profile = Get-SelectedProfile
    $script:LastProfileName = [string]$profile.DisplayName
    $audit = Invoke-GuidedAudit
    $cards = @(Convert-AuditToGuidedCards -Audit $audit -ProfileId $profile.Id)
    $queue = @(Get-RecommendedActionQueue -Cards $cards -ProfileId $profile.Id)
    $verdict = Get-ReadinessVerdict -Cards $cards

    $script:LastCards = $cards
    $script:LastQueue = $queue
    $script:LastVerdict = $verdict

    $ReadyCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Good' }).Count
    $ReviewCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Review' }).Count
    $FixCount.Text = [string]@($cards | Where-Object { $_.Status -eq 'Fix' }).Count
    $VerdictText.Text = "$verdict - $($profile.DisplayName)"

    $cardLines = foreach ($card in $cards) {
        "[$($card.Status)] $($card.Area)`r`n  What this means: $($card.Meaning)`r`n  What to do: $($card.Action)`r`n  Risk: $($card.Risk)`r`n  Backup/undo: $($card.UndoPath)`r`n"
    }
    Set-TextBoxLines -TextBox $CardsBox -Lines $cardLines

    $queueLines = foreach ($item in $queue) {
        "$($item.Action)`r`n  What it changes: $($item.WhatItChanges)`r`n  Why it matters: $($item.WhyItMatters)`r`n  Risk: $($item.Risk)`r`n  Backup/undo path: $($item.BackupUndoPath)`r`n  Reboot required: $($item.RequiresReboot)`r`n  Status: $($item.Status)`r`n"
    }
    Set-TextBoxLines -TextBox $QueueBox -Lines $queueLines

    $detailLines = @(
        "Profile: $($profile.Id)",
        "Audit generated: $($audit.GeneratedAt)",
        '',
        'Raw card evidence:'
    )
    foreach ($card in $cards) {
        $detailLines += "[$($card.Area)] $($card.Details)"
    }
    Set-TextBoxLines -TextBox $DetailsBox -Lines $detailLines
}

$Window.FindName('AuditBtn').Add_Click({
    try {
        Refresh-GuidedView
    } catch {
        $VerdictText.Text = 'Audit failed before readiness could be calculated.'
        $CardsBox.Text = $_.Exception.Message
    }
})

$Window.FindName('ReportBtn').Add_Click({
    try {
        if ($script:LastCards.Count -eq 0) { Refresh-GuidedView }
        $path = Write-GuidedReport -Cards $script:LastCards -Queue $script:LastQueue -Verdict $script:LastVerdict -ProfileName $script:LastProfileName -RoutineSteps @(Get-CurrentRoutineState) -SessionFocus $SessionFocusBox.Text
        [System.Windows.MessageBox]::Show("Report saved:`r`n$path", 'GPTOPT Guided Control Center') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Guided Control Center') | Out-Null
    }
})

$Window.FindName('AdvancedBtn').Add_Click({
    $entry = if (Test-Path -LiteralPath $AdvancedControlCenter) { $AdvancedControlCenter } else { $LegacyControlCenter }
    if (Test-Path -LiteralPath $entry) {
        Start-Process powershell.exe -WorkingDirectory $Root -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$entry`"" | Out-Null
    } else {
        [System.Windows.MessageBox]::Show('Advanced Control Center entry was not found.', 'GPTOPT Guided Control Center') | Out-Null
    }
})

$DetailsToggle.Add_Checked({ $DetailsBox.Visibility = 'Visible' })
$DetailsToggle.Add_Unchecked({ $DetailsBox.Visibility = 'Collapsed' })
$Window.FindName('ResetRoutineBtn').Add_Click({ Initialize-Routine; $SessionFocusBox.Clear() })
$ProfileBox.Add_SelectionChanged({
    if ($ProfileBox.SelectedIndex -ge 0) {
        Initialize-Routine
        Refresh-GuidedView
    }
})

Initialize-Routine
Refresh-GuidedView
$Window.ShowDialog() | Out-Null
