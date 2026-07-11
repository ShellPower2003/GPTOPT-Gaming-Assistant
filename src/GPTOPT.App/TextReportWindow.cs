using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace GPTOPT.App;

public sealed class TextReportWindow : Window
{
    private readonly TextBox _textBox;

    public TextReportWindow(string title, string content)
    {
        Title = title;
        Width = 980;
        Height = 720;
        MinWidth = 720;
        MinHeight = 500;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = new SolidColorBrush(Color.FromRgb(9, 13, 20));
        Foreground = Brushes.White;

        var grid = new Grid { Margin = new Thickness(16) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var heading = new TextBlock
        {
            Text = title,
            FontSize = 24,
            FontWeight = FontWeights.Bold,
            Margin = new Thickness(0, 0, 0, 12)
        };
        Grid.SetRow(heading, 0);
        grid.Children.Add(heading);

        _textBox = new TextBox
        {
            Text = content,
            IsReadOnly = true,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.NoWrap,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            FontFamily = new FontFamily("Consolas"),
            FontSize = 13,
            Background = new SolidColorBrush(Color.FromRgb(12, 18, 28)),
            Foreground = new SolidColorBrush(Color.FromRgb(221, 228, 238)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(38, 51, 71)),
            Padding = new Thickness(12)
        };
        Grid.SetRow(_textBox, 1);
        grid.Children.Add(_textBox);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0)
        };
        var copy = new Button { Content = "Copy", Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(4) };
        copy.Click += (_, _) => Clipboard.SetText(_textBox.Text);
        var save = new Button { Content = "Save As...", Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(4) };
        save.Click += (_, _) => SaveReport();
        var close = new Button { Content = "Close", Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(4) };
        close.Click += (_, _) => Close();
        buttons.Children.Add(copy);
        buttons.Children.Add(save);
        buttons.Children.Add(close);
        Grid.SetRow(buttons, 2);
        grid.Children.Add(buttons);

        Content = grid;
    }

    private void SaveReport()
    {
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Filter = "Text report (*.txt)|*.txt|All files (*.*)|*.*",
            FileName = $"GPTOPT-Report-{DateTime.Now:yyyyMMdd-HHmmss}.txt"
        };
        if (dialog.ShowDialog(this) == true) File.WriteAllText(dialog.FileName, _textBox.Text);
    }
}
