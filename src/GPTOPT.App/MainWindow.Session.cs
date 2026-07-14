using System.Windows;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow
{
    private readonly SessionCaptureService _sessionCaptureService = new();
    private readonly ExperimentOutcomeService _experimentOutcomeService = new();
    private readonly SessionTrendService _sessionTrendService = new();

    private void AnalyzeLatestSession_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            StatusText.Text = "Finding the newest performance capture...";
            var pair = _sessionCaptureService.FindLatestPair();
            var report = _comparisonService.Analyze(pair.Latest);

            if (pair.Previous is not null)
            {
                var comparison = _comparisonService.Compare(pair.Previous, pair.Latest);
                report += "\n\n" + comparison;

                var outcome = _experimentOutcomeService.RecordLatestOutcome(comparison, pair.Previous, pair.Latest);
                if (!string.IsNullOrWhiteSpace(outcome))
                    report += $"\n\nEXPERIMENT UPDATE\n{outcome}\nOpen History → Experiment Ledger to review the linked hypothesis, rollback point, and measured outcome.";

                StatusText.Text = "Latest session analyzed and compared to the prior matching capture.";
                StatusDetailText.Text = $"Latest: {Path.GetFileName(pair.Latest)} • Previous: {Path.GetFileName(pair.Previous)}";
            }
            else
            {
                report += "\n\nNo prior equivalent capture was found automatically. Record another equivalent run to unlock a keep-or-rollback verdict and close the latest experiment.";
                StatusText.Text = "Latest session analyzed.";
                StatusDetailText.Text = Path.GetFileName(pair.Latest);
            }

            var recent = _sessionCaptureService.FindRecentCaptures(8);
            report += "\n\n" + _sessionTrendService.BuildTrendReport(recent);

            new TextReportWindow("GPTOPT Latest Session", report) { Owner = this }.ShowDialog();
        }
        catch (Exception ex)
        {
            StatusText.Text = "Latest-session analysis could not run.";
            StatusDetailText.Text = ex.Message;
            MessageBox.Show(ex.Message, "GPTOPT Session Analysis", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private void ShowCaptureDiscovery_Click(object sender, RoutedEventArgs e)
    {
        var report = _sessionCaptureService.BuildDiscoveryReport();
        new TextReportWindow("GPTOPT Capture Discovery", report) { Owner = this }.ShowDialog();
    }
}