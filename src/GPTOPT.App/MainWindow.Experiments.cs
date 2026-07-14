using System.Windows;
using System.Windows.Controls;
using GPTOPT.App.Services;

namespace GPTOPT.App;

public partial class MainWindow
{
    private readonly ExperimentHistoryService _experimentHistoryService = new();

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        AddExperimentLedgerButton();
    }

    private void AddExperimentLedgerButton()
    {
        if (HistoryList.Parent is not Grid grid) return;
        var panel = grid.Children.OfType<StackPanel>().FirstOrDefault(x => Grid.GetColumn(x) == 1);
        if (panel is null || panel.Children.OfType<Button>().Any(x => Equals(x.Tag, "experiment-ledger"))) return;

        var button = new Button
        {
            Content = "Open Experiment Ledger",
            Tag = "experiment-ledger",
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(4, 8, 4, 4),
            Padding = new Thickness(16, 9, 16, 9)
        };
        button.Click += (_, _) =>
        {
            var report = _experimentHistoryService.BuildReport();
            new TextReportWindow("GPTOPT Experiment Ledger", report) { Owner = this }.ShowDialog();
            StatusText.Text = "Experiment ledger opened.";
            StatusDetailText.Text = "Applied is not improved until verification and equivalent captures support the result";
        };
        panel.Children.Add(button);
    }
}