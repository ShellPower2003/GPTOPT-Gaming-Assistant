param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

$Root = Split-Path -Parent $PSScriptRoot
$KnowledgeDir = Join-Path $Root 'Knowledge'
$ReportsDir = Join-Path $Root 'Reports'
$UserDataDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GPTOPT\Sessions'
$HealthModelPath = Join-Path $KnowledgeDir 'gptopt-health-model.json'
$ProfileSchemaPath = Join-Path $KnowledgeDir 'game-profile-schema.json'
$GuidanceLibraryPath = Join-Path $KnowledgeDir 'gptopt-guidance-library.json'
$SessionAppCatalogPath = Join-Path $KnowledgeDir 'session-app-catalog.json'
$SafetyScanner = Join-Path $PSScriptRoot 'Test-GPTOPTSafety.ps1'
$AdvancedControlCenter = Join-Path $PSScriptRoot 'Invoke-GPTOPTControlCenter.ps1'
$LegacyControlCenter = Join-Path $PSScriptRoot 'Invoke-GPTOPTAppGUI.ps1'
$SessionInsightsModule = Join-Path $PSScriptRoot 'GPTOPT.SessionInsights.ps1'
$SessionStackModule = Join-Path $PSScriptRoot 'GPTOPT.SessionStack.ps1'

New-Item -ItemType Directory -Force -Path $ReportsDir,$UserDataDir | Out-Null

if (-not (Test-Path -LiteralPath $SessionInsightsModule)) {
    throw "Session insights module not found: $SessionInsightsModule"
}
. $SessionInsightsModule
if (-not (Test-Path -LiteralPath $SessionStackModule)) {
    throw "Session stack module not found: $SessionStackModule"
}
. $SessionStackModule

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

function Get-GuidanceEntries {
    param([string]$ProfileId)

    $library = Read-JsonFile -Path $GuidanceLibraryPath -Fallback ([pscustomobject]@{ entries = @() })
    @($library.entries | Where-Object {
        $appliesTo = @($_.appliesTo)
        $appliesTo -contains 'all' -or $appliesTo -contains $ProfileId
    })
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
        $reviewQuestions = @()
        if (
            $profile.PSObject.Properties.Name -contains 'playerLayer' -and
            $profile.playerLayer.PSObject.Properties.Name -contains 'warmup' -and
            $profile.playerLayer.warmup.PSObject.Properties.Name -contains 'learnFrom'
        ) {
            $reviewQuestions = @($profile.playerLayer.warmup.learnFrom)
        }
        $profiles.Add([pscustomobject]@{
            Id = [string]$profile.id
            DisplayName = [string]$profile.name
            Status = [string]$profile.status
            Role = [string]$profile.role
            WarmupRoutine = $routine
            ReviewQuestions = $reviewQuestions
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
        $reviewQuestions = @()
        if ($profile.PSObject.Properties.Name -contains 'reviewQuestions') {
            $reviewQuestions = @($profile.reviewQuestions)
        }
        $profiles.Add([pscustomobject]@{
            Id = [string]$profile.id
            DisplayName = [string]$profile.displayName
            Status = [string]$profile.status
            Role = [string]$profile.role
            WarmupRoutine = $routine
            ReviewQuestions = $reviewQuestions
        })
    }

    if ($profiles.Count -eq 0) {
        $profiles.Add([pscustomobject]@{
            Id = 'generic.shooter'
            DisplayName = 'Generic Competitive Shooter'
            Status = 'experimental'
            Role = 'fallback profile'
            WarmupRoutine = @('Confirm input device', 'Confirm audio route', 'Run movement warmup', 'Run aim warmup', 'Play one low-stress match')
            ReviewQuestions = @('Did input feel consistent?', 'Was audio routing correct?', 'Did the warmup prepare you?', 'What should change next session?')
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
    $detectLevelTwo = $text -match '(?im)^\s*ApplicationDetectionLevel\s*=\s*2\s*$'
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
        [string]$SessionFocus = '',
        [object]$Insights = $null,
        [object[]]$SessionStack = @()
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
    if ($SessionStack.Count -gt 0) {
        $lines += ''
        $lines += '## Session Setup'
        foreach ($app in $SessionStack) {
            $lines += "- [$($app.Status)] $($app.DisplayName) ($($app.Role)): $($app.Why)"
        }
    }
    if ($null -ne $Insights) {
        $lines += ''
        $lines += '## Session Insights'
        foreach ($line in @($Insights.SummaryLines)) {
            $lines += "- $line"
        }
        $lines += ''
        $lines += '### Next Session Recommendations'
        foreach ($recommendation in @($Insights.Recommendations)) {
            $lines += "- $recommendation"
        }
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

function Get-ComboBoxValue {
    param([object]$ComboBox)

    if ($ComboBox.SelectedItem) {
        return [string]$ComboBox.SelectedItem.Content
    }
    return ''
}

function Save-SessionReview {
    param(
        [object]$Profile,
        [string]$Rating,
        [string]$InputFeel,
        [string]$AudioConfidence,
        [string]$WarmupOutcome,
        [string]$Notes
    )

    $routine = @(Get-CurrentRoutineState)
    $review = [pscustomobject]@{
        Version = 1
        RecordedAt = (Get-Date).ToString('o')
        ProfileId = [string]$Profile.Id
        ProfileName = [string]$Profile.DisplayName
        ReadinessVerdict = $script:LastVerdict
        SessionFocus = $SessionFocusBox.Text.Trim()
        RoutineCompleted = @($routine | Where-Object { $_.Complete }).Count
        RoutineTotal = $routine.Count
        Rating = $Rating
        InputFeel = $InputFeel
        AudioConfidence = $AudioConfidence
        WarmupOutcome = $WarmupOutcome
        Notes = $Notes.Trim()
    }

    $path = Join-Path $UserDataDir ("session_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
    $review | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Get-RecentSessionReviews {
    param([int]$Maximum = 5)

    $files = @(Get-ChildItem -LiteralPath $UserDataDir -File -Filter 'session_*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Maximum)
    foreach ($file in $files) {
        try {
            Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
        } catch {
            continue
        }
    }
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
      <TabItem Header="Session Setup">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" LastChildFill="True">
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
              <Button Name="RefreshStackBtn" Content="Refresh" Width="90" Height="34" Margin="8,0,0,0"/>
              <Button Name="PrepareSessionBtn" Content="Prepare Session" Width="140" Height="34" Margin="8,0,0,0"/>
            </StackPanel>
            <StackPanel>
              <TextBlock Text="Session Setup" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBlock Name="SessionStackStatusText" Text="Checks the selected profile's installed session apps." TextWrapping="Wrap" Foreground="#B8C0C8" Margin="0,4,0,14"/>
            </StackPanel>
          </DockPanel>
          <TextBox Grid.Row="1" Name="SessionStackBox" Height="430" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,10,0,0"/>
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
      <TabItem Header="Session Review">
        <Grid Margin="14">
          <Grid.ColumnDefinitions><ColumnDefinition Width="3*"/><ColumnDefinition Width="2*"/></Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0" Margin="0,0,16,0">
            <TextBlock Text="Post-Session Review" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBlock Name="ReviewPromptText" TextWrapping="Wrap" Foreground="#B8C0C8" Margin="0,4,0,14"/>
            <UniformGrid Columns="2" Margin="0,0,0,10">
              <StackPanel Margin="0,0,8,8"><TextBlock Text="Session Rating" Foreground="#F4F4F4"/><ComboBox Name="RatingBox" Margin="0,4,0,0"><ComboBoxItem Content="5 - Excellent"/><ComboBoxItem Content="4 - Strong"/><ComboBoxItem Content="3 - Mixed"/><ComboBoxItem Content="2 - Off"/><ComboBoxItem Content="1 - Poor"/></ComboBox></StackPanel>
              <StackPanel Margin="8,0,0,8"><TextBlock Text="Input Feel" Foreground="#F4F4F4"/><ComboBox Name="InputFeelBox" Margin="0,4,0,0"><ComboBoxItem Content="Consistent"/><ComboBoxItem Content="Over-aiming"/><ComboBoxItem Content="Under-aiming"/><ComboBoxItem Content="Delayed"/><ComboBoxItem Content="Unclear"/></ComboBox></StackPanel>
              <StackPanel Margin="0,0,8,8"><TextBlock Text="Audio Confidence" Foreground="#F4F4F4"/><ComboBox Name="AudioConfidenceBox" Margin="0,4,0,0"><ComboBoxItem Content="Clear"/><ComboBoxItem Content="Mostly clear"/><ComboBoxItem Content="Wrong route"/><ComboBoxItem Content="Hard to locate"/><ComboBoxItem Content="Not assessed"/></ComboBox></StackPanel>
              <StackPanel Margin="8,0,0,8"><TextBlock Text="Warmup Outcome" Foreground="#F4F4F4"/><ComboBox Name="WarmupOutcomeBox" Margin="0,4,0,0"><ComboBoxItem Content="Ready"/><ComboBoxItem Content="Needed more"/><ComboBoxItem Content="Skipped"/><ComboBoxItem Content="Made no difference"/></ComboBox></StackPanel>
            </UniformGrid>
            <TextBlock Text="What happened and what should change next session?" Foreground="#F4F4F4"/>
            <TextBox Name="ReviewNotesBox" Height="100" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" Margin="0,6,0,10"/>
            <Button Name="SaveReviewBtn" Content="Save Session Review" Width="170" Height="36" HorizontalAlignment="Left"/>
          </StackPanel>
          <StackPanel Grid.Column="1">
            <TextBlock Text="Recent Sessions" FontSize="18" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBox Name="RecentReviewsBox" Height="390" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Insights">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel>
            <TextBlock Text="Your Session Patterns" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBlock Name="InsightsStatusText" Text="Session reviews become profile-specific recommendations after you play." TextWrapping="Wrap" Foreground="#B8C0C8" Margin="0,4,0,14"/>
          </StackPanel>
          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="3*"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,14,0">
              <TextBlock Text="What the history shows" FontSize="17" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBox Name="InsightSummaryBox" Height="360" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1">
              <TextBlock Text="Next session priorities" FontSize="17" FontWeight="Bold" Foreground="#F4F4F4"/>
              <TextBox Name="InsightRecommendationsBox" Height="360" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas" Margin="0,8,0,0"/>
            </StackPanel>
          </Grid>
        </Grid>
      </TabItem>
      <TabItem Header="Why This Matters">
        <Grid Margin="14">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel>
            <TextBlock Text="Evidence Behind the Guidance" FontSize="22" FontWeight="Bold" Foreground="#F4F4F4"/>
            <TextBlock Text="GPTOPT separates tested baselines, safety contracts, and product learning rules. Technical evidence stays available without becoming the main workflow." TextWrapping="Wrap" Foreground="#B8C0C8" Margin="0,4,0,14"/>
          </StackPanel>
          <TextBox Grid.Row="1" Name="GuidanceBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080A0C" Foreground="#ECEFF1" FontFamily="Consolas"/>
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
$ReviewPromptText = $Window.FindName('ReviewPromptText')
$RatingBox = $Window.FindName('RatingBox')
$InputFeelBox = $Window.FindName('InputFeelBox')
$AudioConfidenceBox = $Window.FindName('AudioConfidenceBox')
$WarmupOutcomeBox = $Window.FindName('WarmupOutcomeBox')
$ReviewNotesBox = $Window.FindName('ReviewNotesBox')
$RecentReviewsBox = $Window.FindName('RecentReviewsBox')
$GuidanceBox = $Window.FindName('GuidanceBox')
$InsightsStatusText = $Window.FindName('InsightsStatusText')
$InsightSummaryBox = $Window.FindName('InsightSummaryBox')
$InsightRecommendationsBox = $Window.FindName('InsightRecommendationsBox')
$SessionStackStatusText = $Window.FindName('SessionStackStatusText')
$SessionStackBox = $Window.FindName('SessionStackBox')

$Profiles = @(Get-GuidedProfiles)
foreach ($profile in $Profiles) {
    [void]$ProfileBox.Items.Add($profile.DisplayName)
}
$ProfileBox.SelectedIndex = 0

$script:LastCards = @()
$script:LastQueue = @()
$script:LastVerdict = 'Not audited'
$script:LastProfileName = [string]$Profiles[0].DisplayName
$script:LastInsights = $null
$script:LastSessionStack = @()

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

function Initialize-SessionReview {
    $profile = Get-SelectedProfile
    $questions = @($profile.ReviewQuestions | Where-Object { $_ })
    if ($questions.Count -eq 0) {
        $questions = @('Did input feel consistent?', 'Was audio routing correct?', 'Did the warmup prepare you?', 'What should change next session?')
    }
    $ReviewPromptText.Text = ($questions | ForEach-Object { "- $_" }) -join "`r`n"
}

function Update-RecentReviews {
    $reviews = @(Get-RecentSessionReviews)
    if ($reviews.Count -eq 0) {
        $RecentReviewsBox.Text = 'No saved sessions yet.'
        return
    }

    $lines = foreach ($review in $reviews) {
        $date = try { [datetime]$review.RecordedAt } catch { $null }
        $label = if ($date) { $date.ToString('MMM d, h:mm tt') } else { [string]$review.RecordedAt }
        "$label - $($review.ProfileName)`r`n  Rating: $($review.Rating)`r`n  Input: $($review.InputFeel) | Audio: $($review.AudioConfidence)`r`n  Warmup: $($review.WarmupOutcome) | Routine: $($review.RoutineCompleted)/$($review.RoutineTotal)`r`n  Focus: $($review.SessionFocus)`r`n"
    }
    Set-TextBoxLines -TextBox $RecentReviewsBox -Lines $lines
}

function Refresh-SessionStack {
    $profile = Get-SelectedProfile
    $catalog = Read-JsonFile -Path $SessionAppCatalogPath -Fallback ([pscustomobject]@{ apps = @(); profiles = @() })
    $plan = @(Get-GPTOPTSessionStackPlan -Catalog $catalog -ProfileId $profile.Id)
    $script:LastSessionStack = $plan

    $running = @($plan | Where-Object { $_.Status -eq 'Running' }).Count
    $ready = @($plan | Where-Object { $_.Status -eq 'ReadyToStart' }).Count
    $SessionStackStatusText.Text = "$running running, $ready ready to start for $($profile.DisplayName)."

    $lines = foreach ($app in $plan) {
        "[$($app.Status)] $($app.DisplayName) - $($app.Role)`r`n  Why: $($app.Why)`r`n  Risk: $($app.Risk)`r`n  Undo: $($app.Undo)`r`n"
    }
    if ($lines.Count -eq 0) {
        $lines = @('No session-app mapping exists for this profile.')
    }
    Set-TextBoxLines -TextBox $SessionStackBox -Lines $lines
}

function Refresh-Insights {
    $profile = Get-SelectedProfile
    $reviews = @(Get-RecentSessionReviews -Maximum 30)
    $insights = Get-GPTOPTSessionInsights -Reviews $reviews -ProfileId $profile.Id -WindowSize 30
    $script:LastInsights = $insights
    $InsightsStatusText.Text = "$($insights.SessionCount) review(s) analyzed for $($profile.DisplayName)."

    Set-TextBoxLines -TextBox $InsightSummaryBox -Lines @($insights.SummaryLines)
    $recommendationLines = for ($index = 0; $index -lt $insights.Recommendations.Count; $index++) {
        "$($index + 1). $($insights.Recommendations[$index])"
    }
    Set-TextBoxLines -TextBox $InsightRecommendationsBox -Lines $recommendationLines
}

function Refresh-Guidance {
    $profile = Get-SelectedProfile
    $entries = @(Get-GuidanceEntries -ProfileId $profile.Id)
    if ($entries.Count -eq 0) {
        $GuidanceBox.Text = 'No guidance evidence is registered for this profile yet.'
        return
    }

    $lines = foreach ($entry in $entries) {
        "$($entry.title)`r`n  What GPTOPT says: $($entry.summary)`r`n  Why it matters: $($entry.whyItMatters)`r`n  Evidence: $($entry.evidenceType) | Confidence: $($entry.confidence)`r`n  Source: $($entry.sourceLabel) [$($entry.sourcePath)]`r`n  Checked: $($entry.verifiedOn)`r`n  Limits: $($entry.caveat)`r`n"
    }
    Set-TextBoxLines -TextBox $GuidanceBox -Lines $lines
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
        $path = Write-GuidedReport -Cards $script:LastCards -Queue $script:LastQueue -Verdict $script:LastVerdict -ProfileName $script:LastProfileName -RoutineSteps @(Get-CurrentRoutineState) -SessionFocus $SessionFocusBox.Text -Insights $script:LastInsights -SessionStack $script:LastSessionStack
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
$Window.FindName('RefreshStackBtn').Add_Click({ Refresh-SessionStack })
$Window.FindName('PrepareSessionBtn').Add_Click({
    try {
        Refresh-SessionStack
        $launchable = @($script:LastSessionStack | Where-Object { $_.Status -eq 'ReadyToStart' })
        if ($launchable.Count -eq 0) {
            [System.Windows.MessageBox]::Show('No installed session apps need to be started. Missing and manual items were left unchanged.', 'GPTOPT Session Setup') | Out-Null
            return
        }

        $names = ($launchable.DisplayName | ForEach-Object { "- $_" }) -join "`r`n"
        $message = "Start these existing applications?`r`n`r`n$names`r`n`r`nGPTOPT will not install software, edit settings, launch the game, stop processes, or replace Timer Holder."
        $choice = [System.Windows.MessageBox]::Show($message, 'Prepare Session', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($choice -ne [System.Windows.MessageBoxResult]::Yes) { return }

        $results = @(Invoke-GPTOPTSessionStackPlan -Plan $script:LastSessionStack -Confirm:$false)
        $resultLines = @($results | Where-Object { $_.Outcome -ne 'Skipped' } | ForEach-Object { "$($_.DisplayName): $($_.Outcome)" })
        Refresh-SessionStack
        [System.Windows.MessageBox]::Show(($resultLines -join "`r`n"), 'GPTOPT Session Setup') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Session Setup') | Out-Null
    }
})
$Window.FindName('ResetRoutineBtn').Add_Click({ Initialize-Routine; $SessionFocusBox.Clear() })
$Window.FindName('SaveReviewBtn').Add_Click({
    try {
        $path = Save-SessionReview -Profile (Get-SelectedProfile) -Rating (Get-ComboBoxValue $RatingBox) -InputFeel (Get-ComboBoxValue $InputFeelBox) -AudioConfidence (Get-ComboBoxValue $AudioConfidenceBox) -WarmupOutcome (Get-ComboBoxValue $WarmupOutcomeBox) -Notes $ReviewNotesBox.Text
        $ReviewNotesBox.Clear()
        Update-RecentReviews
        Refresh-Insights
        [System.Windows.MessageBox]::Show("Session review saved:`r`n$path", 'GPTOPT Guided Control Center') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'GPTOPT Guided Control Center') | Out-Null
    }
})
$ProfileBox.Add_SelectionChanged({
    if ($ProfileBox.SelectedIndex -ge 0) {
        Initialize-Routine
        Initialize-SessionReview
        Refresh-SessionStack
        Refresh-Insights
        Refresh-Guidance
        Refresh-GuidedView
    }
})

$RatingBox.SelectedIndex = 2
$InputFeelBox.SelectedIndex = 0
$AudioConfidenceBox.SelectedIndex = 0
$WarmupOutcomeBox.SelectedIndex = 0
Initialize-Routine
Initialize-SessionReview
Update-RecentReviews
Refresh-SessionStack
Refresh-Insights
Refresh-Guidance
Refresh-GuidedView
$Window.ShowDialog() | Out-Null
