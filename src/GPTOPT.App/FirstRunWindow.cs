using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace GPTOPT.App;

public sealed class FirstRunWindow : Window
{
    public bool StartWorkflow { get; private set; }

    public FirstRunWindow()
    {
        Title = "Welcome to GPTOPT";
        Width = 760;
        Height = 650;
        MinWidth = 680;
        MinHeight = 560;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Color.FromRgb(7, 10, 16));
        Foreground = Brushes.White;
        ResizeMode = ResizeMode.CanResize;

        var root = new Grid { Margin = new Thickness(34) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new StackPanel { Margin = new Thickness(0, 0, 0, 24) };
        header.Children.Add(new TextBlock
        {
            Text = "GPTOPT",
            FontSize = 38,
            FontWeight = FontWeights.Bold
        });
        header.Children.Add(new TextBlock
        {
            Text = "Your first Halo validation run",
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 8, 0, 0)
        });
        header.Children.Add(new TextBlock
        {
            Text = "GPTOPT does not promise a boost. It prepares the system, records evidence, and decides whether a change should be kept or rolled back.",
            Foreground = new SolidColorBrush(Color.FromRgb(149, 165, 186)),
            TextWrapping = TextWrapping.Wrap,
            FontSize = 14,
            Margin = new Thickness(0, 8, 0, 0)
        });
        Grid.SetRow(header, 0);
        root.Children.Add(header);

        var steps = new StackPanel();
        steps.Children.Add(BuildStep("1", "Prepare", "Run the readiness check. GPTOPT classifies hardware, Windows, controller, network, and reboot evidence."));
        steps.Children.Add(BuildStep("2", "Play", "Play one normal Halo match. Keep RTSS, CapFrameX/PresentMon, Flydigi SpaceStation, Sonar, and Afterburner running."));
        steps.Children.Add(BuildStep("3", "Analyze", "GPTOPT finds the newest performance capture, rates capture quality, and compares a plausible prior run."));
        steps.Children.Add(BuildStep("4", "Decide", "The active experiment becomes KEEP CANDIDATE, ROLLBACK CANDIDATE, or INCONCLUSIVE. Applied never automatically means improved."));

        var policy = new Border
        {
            Background = new SolidColorBrush(Color.FromRgb(16, 27, 41)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(43, 67, 94)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(18),
            Margin = new Thickness(0, 12, 0, 0),
            Child = new TextBlock
            {
                Text = "Preserved by design: Flydigi SpaceStation, SteelSeries Sonar, RTSS, MSI Afterburner, CapFrameX, wired controller operation, and user-selected Halo settings. GPTOPT does not kill these tools, force a reboot, inject input, or manipulate Halo process priority.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = new SolidColorBrush(Color.FromRgb(199, 210, 224))
            }
        };
        steps.Children.Add(policy);

        var scroll = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = steps
        };
        Grid.SetRow(scroll, 1);
        root.Children.Add(scroll);

        var actions = new Grid { Margin = new Thickness(0, 24, 0, 0) };
        actions.ColumnDefinitions.Add(new ColumnDefinition());
        actions.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        actions.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var skip = BuildButton("Open Dashboard", false);
        skip.Click += (_, _) => { StartWorkflow = false; DialogResult = true; };
        Grid.SetColumn(skip, 1);
        actions.Children.Add(skip);

        var start = BuildButton("Start First Halo Test", true);
        start.Click += (_, _) => { StartWorkflow = true; DialogResult = true; };
        Grid.SetColumn(start, 2);
        actions.Children.Add(start);

        Grid.SetRow(actions, 2);
        root.Children.Add(actions);
        Content = root;
    }

    private static Border BuildStep(string number, string title, string description)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(48) });
        grid.ColumnDefinitions.Add(new ColumnDefinition());

        var badge = new Border
        {
            Width = 38,
            Height = 38,
            CornerRadius = new CornerRadius(19),
            Background = new SolidColorBrush(Color.FromRgb(39, 133, 232)),
            VerticalAlignment = VerticalAlignment.Top,
            Child = new TextBlock
            {
                Text = number,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                FontWeight = FontWeights.Bold,
                FontSize = 16
            }
        };
        grid.Children.Add(badge);

        var copy = new StackPanel { Margin = new Thickness(8, 0, 0, 0) };
        copy.Children.Add(new TextBlock { Text = title, FontSize = 18, FontWeight = FontWeights.Bold });
        copy.Children.Add(new TextBlock
        {
            Text = description,
            TextWrapping = TextWrapping.Wrap,
            Foreground = new SolidColorBrush(Color.FromRgb(149, 165, 186)),
            Margin = new Thickness(0, 4, 0, 0)
        });
        Grid.SetColumn(copy, 1);
        grid.Children.Add(copy);

        return new Border
        {
            Background = new SolidColorBrush(Color.FromRgb(17, 24, 36)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(42, 59, 81)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16),
            Margin = new Thickness(0, 0, 0, 10),
            Child = grid
        };
    }

    private static Button BuildButton(string text, bool primary) => new()
    {
        Content = text,
        Padding = new Thickness(20, 11, 20, 11),
        Margin = new Thickness(8, 0, 0, 0),
        Foreground = Brushes.White,
        FontWeight = FontWeights.SemiBold,
        Background = new SolidColorBrush(primary ? Color.FromRgb(39, 133, 232) : Color.FromRgb(27, 42, 62)),
        BorderBrush = new SolidColorBrush(primary ? Color.FromRgb(115, 185, 255) : Color.FromRgb(53, 81, 111)),
        BorderThickness = new Thickness(1),
        Cursor = System.Windows.Input.Cursors.Hand
    };
}