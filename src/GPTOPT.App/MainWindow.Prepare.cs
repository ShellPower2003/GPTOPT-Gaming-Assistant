using System.Windows;

namespace GPTOPT.App;

public partial class MainWindow
{
    private async void PrepareForHalo_Click(object sender, RoutedEventArgs e)
    {
        StatusText.Text = "Preparing Halo session...";
        StatusDetailText.Text = "Scanning the PC, then classifying gaming-relevant faults";
        AuditProgress.IsIndeterminate = true;

        try
        {
            await RunAuditAsync(false);

            var progress = new Progress<string>(message => StatusText.Text = message);
            var diagnostics = await _diagnosticsService.BuildReportAsync(progress);
            var report = _auditService.LoadLatest();

            RefreshDashboard();

            if (report is null)
            {
                MessageBox.Show(
                    "The readiness scan completed, but GPTOPT could not load the resulting report.",
                    "Prepare for Halo",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
                return;
            }

            var blockers = new List<string>();
            if (report.Health.ProblemDeviceCount > 0)
                blockers.Add($"{report.Health.ProblemDeviceCount} problem device(s)");
            if (report.Health.PendingRebootCount > 0)
                blockers.Add("Windows has a pending reboot");
            if (!report.Devices.FlydigiDetected)
                blockers.Add("Flydigi/Vader controller path not detected");
            if (report.Devices.ActiveWiredAdapters == 0)
                blockers.Add("no active wired network adapter");

            var result = blockers.Count == 0
                ? "READY FOR HALO\n\nCore Windows, display, network, and controller checks passed. Review the diagnostic detail below only if the game still feels wrong."
                : "NEEDS ATTENTION\n\n" + string.Join("\n", blockers.Select(x => "• " + x));

            StatusText.Text = blockers.Count == 0 ? "Ready for Halo" : "Halo session needs attention";
            StatusDetailText.Text = blockers.Count == 0
                ? "No pre-session blockers detected"
                : string.Join("; ", blockers);

            new TextReportWindow("Prepare for Halo", result + "\n\n" + diagnostics)
            {
                Owner = this
            }.ShowDialog();
        }
        catch (Exception ex)
        {
            StatusText.Text = "Prepare for Halo failed";
            StatusDetailText.Text = ex.Message;
            MessageBox.Show(ex.Message, "Prepare for Halo", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
        }
    }
}
