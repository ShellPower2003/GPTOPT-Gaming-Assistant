using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using GPTOPT.App.Models;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow : Window
{
    private readonly AuditService _auditService = new();
    private readonly RecommendationService _recommendationService = new();
    private readonly OptimizationService _optimizationService = new();
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
            PlatformText.Text = "No audit found. Run a local or published audit.";
            GamingText.Text = DeviceText.Text = HealthText.Text = string.Empty;
            HistoryList.ItemsSource = _auditService.GetHistory();
            AuditIdText.Text = "No audit selected";
            RecommendationList.ItemsSource = null;
            StatusText.Text = "Run an audit to generate recommendations.";
            return;
        }

        PlatformText.Text = $"Audit: {report.AuditId}\nWindows: {report.Platform.Windows} ({report.Platform.Build})\nBIOS: {report.Platform.Bios}\nCPU: {report.Platform.Cpu}\nGPU: {report.Platform.Gpu}\nMemory: {report.Platform.MemoryGb:0.#} GB\nDisplay: {report.Platform.Display}";
        GamingText.Text = $"Power plan: {report.Gaming.PowerPlan}\nGame Mode: {report.Gaming.GameMode}\nGame DVR: {report.Gaming.GameDvr}\nHAGS: {report.Gaming.Hags}\nMPO override: {report.Gaming.MpoOverride}";
        DeviceText.Text = $"Flydigi detected: {report.Devices.FlydigiDetected}\nNVIDIA driver: {report.Devices.NvidiaDriver}\nWired adapters: {report.Devices.ActiveWiredAdapters}\nWi-Fi adapters: {report.Devices.ActiveWifiAdapters}\nRunning: {string.Join(", ", report.Devices.GptoptProcesses)}";
        HealthText.Text = $"System errors (72h): {report.Health.SystemErrorCount}\nApplication errors (72h): {report.Health.ApplicationErrorCount}\nProblem devices: {report.Health.ProblemDeviceCount}\nPending reboot: {report.Health.PendingRebootCount}\nSystem drive free: {report.Health.SystemDriveFreeGb:0.#} GB";
        HistoryList.ItemsSource = _auditService.GetHistory();
        AuditIdText.Text = $"Latest: {report.AuditId}\nCollected UTC: {report.CollectedUtc}";

        _recommendations = _recommendationService.Build(report).ToList();
        RecommendationList.ItemsSource = _recommendations;
        RecommendationList.SelectedIndex = _recommendations.Count > 0 ? 0 : -1;
        StatusText.Text = $"Loaded {_recommendations.Count} explained recommendation(s) from {report.AuditId}.";
    }

    private async Task RunAuditAsync(bool publish)
    {
        LocalAuditButton.IsEnabled = PublishAuditButton.IsEnabled = false;
        AuditProgress.IsIndeterminate = true;
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
        SafetyText.Text = $"Can apply: {item.CanApply}   |   Administrator: {item.RequiresAdmin}   |   Reboot: {item.RequiresReboot}\nGPTOPT creates a rollback snapshot before applying selected supported changes.";
    }

    private async void ApplySelected_Click(object sender, RoutedEventArgs e)
    {
        var selected = _recommendations.Where(x => x.IsSelected && x.CanApply).ToArray();
        if (selected.Length == 0)
        {
            MessageBox.Show("No applicable changes are selected.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var summary = string.Join("\n", selected.Select(x => $"• {x.Title} — Risk: {x.Risk}; Reboot: {x.RequiresReboot}"));
        var confirm = MessageBox.Show($"GPTOPT will apply these selected changes:\n\n{summary}\n\nA rollback snapshot will be created first. Continue?", "Confirm selected changes", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (confirm != MessageBoxResult.Yes) return;

        ApplySelectedButton.IsEnabled = false;
        AuditProgress.IsIndeterminate = true;
        try
        {
            var progress = new Progress<string>(message => StatusText.Text = message);
            var result = await _optimizationService.ApplyAsync(selected, progress);
            StatusText.Text = result + " Run a new audit to verify the resulting state.";
            MessageBox.Show(result, "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
            MessageBox.Show(ex.Message, "GPTOPT Apply Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
            ApplySelectedButton.IsEnabled = true;
        }
    }

    private void SelectSafeDefaults_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in _recommendations)
            item.IsSelected = item.CanApply && item.Risk == "Low" && !item.RequiresAdmin;
        RecommendationList.Items.Refresh();
        StatusText.Text = "Selected low-risk, non-administrator defaults only.";
    }

    private void ClearSelection_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in _recommendations) item.IsSelected = false;
        RecommendationList.Items.Refresh();
        StatusText.Text = "Selection cleared.";
    }

    private async void LocalAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(false);
    private async void PublishAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(true);
    private void RefreshButton_Click(object sender, RoutedEventArgs e) => RefreshDashboard();
    private void RecommendationList_SelectionChanged(object sender, SelectionChangedEventArgs e) => ShowRecommendation(RecommendationList.SelectedItem as OptimizationRecommendation);

    private void OpenAuditStore_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(_auditService.AuditRoot);
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{_auditService.AuditRoot}\"") { UseShellExecute = true });
    }

    private void OpenPresentMon_Click(object sender, RoutedEventArgs e)
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Intel", "PresentMon", "PresentMon.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "PresentMon", "PresentMon.exe")
        };
        var path = candidates.FirstOrDefault(File.Exists);
        if (path is null)
        {
            MessageBox.Show("PresentMon was not found in a standard install location.", "GPTOPT", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }
}
