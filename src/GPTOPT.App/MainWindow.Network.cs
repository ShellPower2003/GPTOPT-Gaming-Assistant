using System.Windows;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow
{
    private readonly NetworkQualityService _networkQualityService = new();

    private async void RunNetworkQuality_Click(object sender, RoutedEventArgs e)
    {
        AuditProgress.IsIndeterminate = true;
        StatusDetailText.Text = "Measuring gateway latency, Internet latency, jitter, loss, DNS, and route evidence";
        try
        {
            var progress = new Progress<string>(message => StatusText.Text = message);
            var report = await _networkQualityService.BuildReportAsync(progress);
            new TextReportWindow("GPTOPT Network Quality", report) { Owner = this }.ShowDialog();
            StatusText.Text = "Network quality measurement complete.";
            StatusDetailText.Text = "Repeat during the exact time Halo feels unstable before changing the network path";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
            StatusDetailText.Text = "Network measurement failed";
            MessageBox.Show(ex.Message, "GPTOPT Network Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            AuditProgress.IsIndeterminate = false;
            AuditProgress.Value = 100;
        }
    }
}