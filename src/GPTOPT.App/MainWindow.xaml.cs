using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using GPTOPT.App.Models;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow : Window
{
    private readonly AuditService _auditService = new();
    private readonly RecommendationService _recommendationService = new();
    private readonly OptimizationService _optimizationService = new();
    private readonly RollbackService _rollbackService = new();
    private readonly DiagnosticsService _diagnosticsService = new();
    private readonly PerformanceComparisonService _comparisonService = new();
    private List<OptimizationRecommendation> _recommendations = [];

    public MainWindow()
    {
        InitializeComponent();
        RefreshDashboard();
    }

    private void RefreshDashboard()
    {
        var report = _auditService.LoadLatest();
        if (report is null)
        {
            PlatformText.Text = "No audit found. Select Check PC to build the first system profile.";
            GamingText.Text = DeviceText.Text = HealthText.Text = string.Empty;
            HistoryList.ItemsSource = _auditService.GetHistory();
            AuditIdText.Text = "No audit loaded";
            RecommendationList.ItemsSource = null;
            HealthGradeText.Text = "--";
            HealthSummaryText.Text = "Run an audit to calculate status";
            SelectionCountText.Text = "0 selected";
            StatusText.Text = "Run an audit to generate explained recommendations.";
            StatusDetailText.Text = "Waiting for first system check";
            return;
        }

        PlatformText.Text = $"Audit: {report.AuditId}\nWindows: {report.Platform.Windows} ({report.Platform.Build})\nBIOS: {report.Platform.Bios}\nCPU: {report.Platform.Cpu}\nGPU: {report.Platform.Gpu}\nMemory: {report.Platform.MemoryGb:0.#} GB\nDisplay: {report.Platform.Display}";
        GamingText.Text = $"Power plan: {report.Gaming.PowerPlan}\nGame Mode: {report.Gaming.GameMode}\nGame DVR: {report.Gaming.GameDvr}\nHAGS: {report.Gaming.Hags}\nMPO override: {report.Gaming.MpoOverride}";
        DeviceText.Text = $"Flydigi detected: {report.Devices.FlydigiDetected}\nNVIDIA driver: {report.Devices.NvidiaDriver}\nWired adapters: {report.Devices.ActiveWiredAdapters}\nWi-Fi adapters: {report.Devices.ActiveWifiAdapters}\nRunning: {string.Join(", ", report.Devices.GptoptProcesses)}";
        HealthText.Text = $"System errors (72h): {report.Health.SystemErrorCount}\nApplication errors (72h): {report.Health.ApplicationErrorCount}\nProblem devices: {report.Health.ProblemDeviceCount}\nPending reboot: {report.Health.PendingRebootCount}\nSystem drive free: {report.Health.SystemDriveFreeGb:0.#} GB";
        HistoryList.ItemsSource = _auditService.GetHistory();
        AuditIdText.Text = $"{report.AuditId}\n{report.CollectedUtc}";

        var score = CalculateHealthScore(report);
        HealthGradeText.Text = score.ToString();
        HealthSummaryText.Text = score >= 90 ? "Strong gaming baseline" : score >= 75 ? "Good, with items to review" : score >= 60 ? "Needs attention" : "Action recommended";
        HealthGradeText.Foreground = score >= 90
            ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(115, 214, 160))
            : score >= 75
                ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 203, 107))
                : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 126, 126));

        _recommendations = _recommendationService.Build(report).ToList();
        ApplyRecommendationFilter();
        RecommendationList.SelectedIndex = RecommendationList.Items.Count > 0 ? 0 : -1;
        UpdateSelectionCount();
        var actionable = _recommendations.Count(x => x.CanApply);
        StatusText.Text = actionable == 0
            ? "No configuration changes are currently recommended. Review diagnostics or measure performance."
            : $"Loaded {actionable} actionable change(s) and {_recommendations.Count - actionable} diagnostic item(s).";
        StatusDetailText.Text = $"Latest local audit: {report.AuditId}";
    }

    private static int CalculateHealthScore(AuditReport report)
    {
        var score = 100;
        score -= Math.Min(report.Health.SystemErrorCount, 10);
        score -= Math.Min(report.Health.ApplicationErrorCount / 3, 10);
        score -= report.Health.ProblemDeviceCount * 8;
        score -= report.Health.PendingRebootCount * 5;
        if (!report.Devices.FlydigiDetected) score -= 5;
        if (report.Devices.ActiveWiredAdapters == 0) score -= 5;
        return Math.Clamp(score, 0, 100);
    }

    private async Task RunAuditAsync(bool publish)
    {
        LocalAuditButton.IsEnabled = PublishAuditButton.IsEnabled = false;
        AuditProgress.IsIndeterminate = true;
        StatusDetailText.Text = publish ? "Collecting and publishing sanitized summary" : "Collecting private local audit";
        var progress = new Progress<string>(message => StatusText.Text = message);
        try
        {
            var exitCode = await _auditService.RunAuditAsync(publish, progress);
            StatusText.Text = exitCode == 0 ? "Audit complete" : $"Audit exited with code {exitCode}";
            RefreshDashboard();
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
            StatusDetailText.Text = "Audit failed";
            MessageBox.Show(ex.Message, "GPTOPT Audit Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
            LocalAuditButton.IsEnabled = PublishAuditButton.IsEnabled = true;
        }
    }

    private void ShowRecommendation(OptimizationRecommendation? item)
    {
        if (item is null)
        {
            RecommendationTitle.Text = "Select a recommendation";
            RecommendationMeta.Text = CurrentStateText.Text = TargetStateText.Text = WhyText.Text = HowText.Text = SafetyText.Text = string.Empty;
            return;
        }

        RecommendationTitle.Text = item.Title;
        RecommendationMeta.Text = $"{item.Category}  •  Impact: {item.ExpectedImpact}  •  Risk: {item.Risk}";
        CurrentStateText.Text = item.CurrentState;
        TargetStateText.Text = item.TargetState;
        WhyText.Text = item.Why;
        HowText.Text = item.How;
        SafetyText.Text = item.CanApply
            ? $"Can apply: Yes   •   Administrator: {YesNo(item.RequiresAdmin)}   •   Reboot: {YesNo(item.RequiresReboot)}\nA rollback snapshot is created before supported changes are applied."
            : $"Diagnostic or guidance item   •   Reboot: {YesNo(item.RequiresReboot)}\nGPTOPT will not apply this automatically because the correct next step depends on evidence or user action.";
    }

    private static string YesNo(bool value) => value ? "Yes" : "No";

    private void ApplyRecommendationFilter()
    {
        var category = (CategoryFilter.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "All";
        var filtered = category == "All"
            ? _recommendations
            : _recommendations.Where(x => string.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase)).ToList();
        RecommendationList.ItemsSource = filtered;
    }

    private void UpdateSelectionCount()
    {
        var count = _recommendations.Count(x => x.IsSelected && x.CanApply);
        SelectionCountText.Text = count == 1 ? "1 selected" : $"{count} selected";
        ApplySelectedButton.IsEnabled = count > 0;
    }

    private void SelectProfile(Func<OptimizationRecommendation, bool> selector, string status)
    {
        foreach (var item in _recommendations)
            item.IsSelected = item.CanApply && selector(item);
        RecommendationList.Items.Refresh();
        UpdateSelectionCount();
        StatusText.Text = status;
        StatusDetailText.Text = "Review every selected action before applying";
    }

    private void SafeGamingProfile_Click(object sender, RoutedEventArgs e) =>
        SelectProfile(item => item.Risk == "Low" && !item.RequiresAdmin && item.Category == "Windows Gaming",
            "Safe Gaming Baseline selected only low-risk user-level gaming settings.");

    private void StabilityProfile_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in _recommendations) item.IsSelected = false;
        CategoryFilter.SelectedIndex = 0;
        ApplyRecommendationFilter();
        var firstDiagnostic = _recommendations.FirstOrDefault(x => x.Category is "Health" or "Devices");
        if (firstDiagnostic is not null) RecommendationList.SelectedItem = firstDiagnostic;
        UpdateSelectionCount();
        StatusText.Text = "Stability Review highlights diagnostics without automatically changing Windows.";
        StatusDetailText.Text = "Run Targeted Diagnostics to identify the device or event category";
    }

    private async void ApplySelected_Click(object sender, RoutedEventArgs e)
    {
        var selected = _recommendations.Where(x => x.IsSelected && x.CanApply).ToArray();
        if (selected.Length == 0)
        {
            MessageBox.Show("No applicable changes are selected.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var summary = string.Join("\n", selected.Select(x => $"• {x.Title} — Risk: {x.Risk}; Admin: {YesNo(x.RequiresAdmin)}; Reboot: {YesNo(x.RequiresReboot)}"));
        var confirm = MessageBox.Show($"Review the selected changes:\n\n{summary}\n\nGPTOPT will create a rollback snapshot first. Continue?", "Review and apply", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (confirm != MessageBoxResult.Yes) return;

        ApplySelectedButton.IsEnabled = false;
        AuditProgress.IsIndeterminate = true;
        StatusDetailText.Text = "Creating rollback snapshot and applying selected actions";
        try
        {
            var progress = new Progress<string>(message => StatusText.Text = message);
            var result = await _optimizationService.ApplyAsync(selected, progress);
            StatusText.Text = result;
            StatusDetailText.Text = "Run Verify Changes to confirm the new state";
            MessageBox.Show(result + "\n\nUse Verify Changes to re-audit the PC.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
            StatusDetailText.Text = "Apply failed; rollback data was preserved when available";
            MessageBox.Show(ex.Message, "GPTOPT Apply Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
            UpdateSelectionCount();
        }
    }

    private void ClearSelection_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in _recommendations) item.IsSelected = false;
        RecommendationList.Items.Refresh();
        UpdateSelectionCount();
        StatusText.Text = "Selection cleared.";
    }

    private async void OpenRollbackManager_Click(object sender, RoutedEventArgs e)
    {
        var snapshots = _rollbackService.GetSnapshots();
        if (snapshots.Count == 0)
        {
            MessageBox.Show("No rollback snapshots exist yet.", "GPTOPT Rollback", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var selected = SelectRollbackSnapshot(snapshots);
        if (selected is null) return;
        var confirm = MessageBox.Show($"Restore this snapshot?\n\n{Path.GetFileName(selected)}\n\nAdministrator approval may be required. GPTOPT will not reboot automatically.", "Confirm rollback", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (confirm != MessageBoxResult.Yes) return;

        AuditProgress.IsIndeterminate = true;
        try
        {
            var progress = new Progress<string>(message => StatusText.Text = message);
            var result = await _rollbackService.RestoreAsync(selected, progress);
            StatusText.Text = result;
            StatusDetailText.Text = "Run Verify Changes to validate the rollback";
            MessageBox.Show(result, "GPTOPT Rollback", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "GPTOPT Rollback Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
        }
    }

    private string? SelectRollbackSnapshot(IReadOnlyList<string> snapshots)
    {
        var window = new Window
        {
            Title = "GPTOPT Rollback Manager",
            Width = 620,
            Height = 420,
            Owner = this,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(9, 13, 20)),
            Foreground = System.Windows.Media.Brushes.White
        };
        var grid = new Grid { Margin = new Thickness(16) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var title = new TextBlock { Text = "Choose a rollback snapshot", FontSize = 22, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 12) };
        var list = new ListBox { ItemsSource = snapshots.Select(Path.GetFileName), SelectedIndex = 0, Background = System.Windows.Media.Brushes.Black, Foreground = System.Windows.Media.Brushes.White };
        var restore = new Button { Content = "Restore Selected", Padding = new Thickness(16, 8, 16, 8), HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 12, 0, 0) };
        restore.Click += (_, _) => window.DialogResult = true;
        Grid.SetRow(title, 0); Grid.SetRow(list, 1); Grid.SetRow(restore, 2);
        grid.Children.Add(title); grid.Children.Add(list); grid.Children.Add(restore); window.Content = grid;
        return window.ShowDialog() == true && list.SelectedIndex >= 0 ? snapshots[list.SelectedIndex] : null;
    }

    private async void RunTargetedDiagnostics_Click(object sender, RoutedEventArgs e)
    {
        AuditProgress.IsIndeterminate = true;
        StatusDetailText.Text = "Classifying devices, events, controller path, and reboot sources";
        try
        {
            var progress = new Progress<string>(message => StatusText.Text = message);
            var report = await _diagnosticsService.BuildReportAsync(progress);
            new TextReportWindow("GPTOPT Targeted Diagnostics", report) { Owner = this }.ShowDialog();
            StatusText.Text = "Targeted diagnostics complete.";
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "GPTOPT Diagnostics Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
        }
    }

    private void CompareCaptures_Click(object sender, RoutedEventArgs e)
    {
        var before = PickCsv("Select BEFORE capture CSV");
        if (before is null) return;
        var after = PickCsv("Select AFTER capture CSV");
        if (after is null) return;
        try
        {
            var report = _comparisonService.Compare(before, after);
            new TextReportWindow("GPTOPT Before / After Comparison", report) { Owner = this }.ShowDialog();
            StatusText.Text = "Performance captures compared.";
            StatusDetailText.Text = "Use repeated equivalent runs before keeping or rolling back a change";
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "GPTOPT Comparison Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private string? PickCsv(string title)
    {
        var dialog = new OpenFileDialog
        {
            Title = title,
            Filter = "Performance CSV (*.csv)|*.csv|All files (*.*)|*.*",
            Multiselect = false
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }

    private async void LocalAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(false);
    private async void PublishAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(true);
    private async void VerifyChanges_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(false);
    private void RefreshButton_Click(object sender, RoutedEventArgs e) => RefreshDashboard();
    private void RecommendationList_SelectionChanged(object sender, SelectionChangedEventArgs e) => ShowRecommendation(RecommendationList.SelectedItem as OptimizationRecommendation);
    private void RecommendationCheckBox_Click(object sender, RoutedEventArgs e) => UpdateSelectionCount();

    private void CategoryFilter_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!IsLoaded) return;
        ApplyRecommendationFilter();
        RecommendationList.SelectedIndex = RecommendationList.Items.Count > 0 ? 0 : -1;
    }

    private void OpenAuditStore_Click(object sender, RoutedEventArgs e) => OpenFolder(_auditService.AuditRoot);

    private void HistoryList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (HistoryList.SelectedItem is not string auditId) return;
        OpenFolder(Path.Combine(_auditService.AuditRoot, auditId));
    }

    private static void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{path}\"") { UseShellExecute = true });
    }

    private static void StartUtility(string fileName, string? arguments = null)
    {
        try
        {
            Process.Start(new ProcessStartInfo(fileName, arguments ?? string.Empty) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "GPTOPT Tool Launch", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private void OpenTaskManager_Click(object sender, RoutedEventArgs e) => StartUtility("taskmgr.exe");
    private void OpenDeviceManager_Click(object sender, RoutedEventArgs e) => StartUtility("devmgmt.msc");
    private void OpenEventViewer_Click(object sender, RoutedEventArgs e) => StartUtility("eventvwr.msc");
    private void OpenWindowsUpdate_Click(object sender, RoutedEventArgs e) => StartUtility("ms-settings:windowsupdate");
    private void OpenControllerCalibration_Click(object sender, RoutedEventArgs e) => StartUtility("control.exe", "joy.cpl");

    private void OpenNvidiaApp_Click(object sender, RoutedEventArgs e)
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "NVIDIA Corporation", "NVIDIA app", "CEF", "NVIDIA app.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "NVIDIA Corporation", "NVIDIA app", "NVIDIA app.exe")
        };
        var path = candidates.FirstOrDefault(File.Exists);
        if (path is null) MessageBox.Show("NVIDIA App was not found in a standard install location.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
        else StartUtility(path);
    }

    private void OpenPresentMon_Click(object sender, RoutedEventArgs e)
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Intel", "PresentMon", "PresentMon.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "PresentMon", "PresentMon.exe")
        };
        var path = candidates.FirstOrDefault(File.Exists);
        if (path is null) MessageBox.Show("PresentMon was not found in a standard install location.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
        else StartUtility(path);
    }
}
