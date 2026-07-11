using System.Diagnostics;
using System.Windows;
using GPTOPT.App.Models;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow : Window
{
    private readonly AuditService _auditService = new();

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
            return;
        }

        PlatformText.Text = $"Audit: {report.AuditId}\nWindows: {report.Platform.Windows} ({report.Platform.Build})\nBIOS: {report.Platform.Bios}\nCPU: {report.Platform.Cpu}\nGPU: {report.Platform.Gpu}\nMemory: {report.Platform.MemoryGb:0.#} GB\nDisplay: {report.Platform.Display}";
        GamingText.Text = $"Power plan: {report.Gaming.PowerPlan}\nGame Mode: {report.Gaming.GameMode}\nGame DVR: {report.Gaming.GameDvr}\nHAGS: {report.Gaming.Hags}\nMPO override: {report.Gaming.MpoOverride}";
        DeviceText.Text = $"Flydigi detected: {report.Devices.FlydigiDetected}\nNVIDIA driver: {report.Devices.NvidiaDriver}\nWired adapters: {report.Devices.ActiveWiredAdapters}\nWi-Fi adapters: {report.Devices.ActiveWifiAdapters}\nRunning: {string.Join(", ", report.Devices.GptoptProcesses)}";
        HealthText.Text = $"System errors (72h): {report.Health.SystemErrorCount}\nApplication errors (72h): {report.Health.ApplicationErrorCount}\nProblem devices: {report.Health.ProblemDeviceCount}\nPending reboot: {report.Health.PendingRebootCount}\nSystem drive free: {report.Health.SystemDriveFreeGb:0.#} GB";
        HistoryList.ItemsSource = _auditService.GetHistory();
        AuditIdText.Text = $"Latest: {report.AuditId}\nCollected UTC: {report.CollectedUtc}";
        StatusText.Text = "Latest audit loaded";
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

    private async void LocalAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(false);
    private async void PublishAuditButton_Click(object sender, RoutedEventArgs e) => await RunAuditAsync(true);
    private void RefreshButton_Click(object sender, RoutedEventArgs e) => RefreshDashboard();

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
