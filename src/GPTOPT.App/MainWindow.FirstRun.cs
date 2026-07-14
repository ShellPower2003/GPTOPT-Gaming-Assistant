using System.Windows;

namespace GPTOPT.App;

public partial class MainWindow
{
    public void BeginFirstHaloTest()
    {
        Dispatcher.BeginInvoke(() =>
        {
            StatusText.Text = "First Halo test started";
            StatusDetailText.Text = "Step 1 of 4: Prepare the system and classify evidence";
            PrepareForHalo_Click(this, new RoutedEventArgs());
        });
    }
}