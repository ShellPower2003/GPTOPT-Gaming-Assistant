using System.Windows;

namespace GPTOPT.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var main = new MainWindow();
        MainWindow = main;

        var markerRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "GPTOPT", "State");
        var marker = Path.Combine(markerRoot, "first-run-v1.complete");
        var showGuide = !File.Exists(marker);

        if (showGuide)
        {
            var guide = new FirstRunWindow();
            var accepted = guide.ShowDialog() == true;
            Directory.CreateDirectory(markerRoot);
            File.WriteAllText(marker, $"Completed UTC: {DateTime.UtcNow:O}");

            main.Show();
            if (accepted && guide.StartWorkflow)
            {
                main.BeginFirstHaloTest();
            }
        }
        else
        {
            main.Show();
        }
    }
}