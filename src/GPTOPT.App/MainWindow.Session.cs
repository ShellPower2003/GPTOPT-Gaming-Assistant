using System.Windows;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow
{
    private readonly SessionCaptureService _sessionCaptureService = new();

    private void AnalyzeLatestSession_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            StatusText.Text = "Finding the newest performance capture...";
            var pair = _sessionCaptureService.FindLatestPair();
            var report = _comparisonService.Analyze(pair.Latest);

            if (pair.Previous is not null)
            {
                report += "\n\n" + _comparisonService.Compare(pair.Previous, pair.Latest);
                StatusText.Text = "Latest session analyzed and compared to the prior matching capture.";
                StatusDetailText.Text = $"Latest: {Path.GetFileName(pair.Latest)} • Previous: {Path.GetFileName(pair.Previous)}";
            }
            else
            {
                report += "\n\nNo prior equivalent capture was found automatically. Record another equivalent run to unlock a keep-or-rollback verdict.";
                StatusText.Text = "Latest session analyzed.";
                StatusDetailText.Text = Path.GetFileName(pair.Latest);
            }

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
