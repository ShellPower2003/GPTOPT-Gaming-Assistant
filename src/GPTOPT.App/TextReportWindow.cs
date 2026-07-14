using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace GPTOPT.App;

public sealed class TextReportWindow : Window
{
    private readonly TextBox _textBox;
    private readonly TextBox _searchBox;
    private readonly TextBlock _searchStatus;
    private int _searchStart;

    public TextReportWindow(string title, string content)
    {
        Title = title;
        Width = 1040;
        Height = 760;
        MinWidth = 760;
        MinHeight = 520;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = new SolidColorBrush(Color.FromRgb(9, 13, 20));
        Foreground = Brushes.White;

        var grid = new Grid { Margin = new Thickness(16) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
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

        var searchBar = new Grid { Margin = new Thickness(0, 0, 0, 10) };
        searchBar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        searchBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        searchBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        searchBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        searchBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _searchBox = new TextBox
        {
            MinWidth = 260,
            Padding = new Thickness(10, 7, 10, 7),
            Background = new SolidColorBrush(Color.FromRgb(17, 26, 39)),
            Foreground = Brushes.White,
            BorderBrush = new SolidColorBrush(Color.FromRgb(53, 81, 111)),
            ToolTip = "Search this report"
        };
        _searchBox.KeyDown += (_, e) => { if (e.Key == Key.Enter) FindNext(); };
        _searchBox.TextChanged += (_, _) => { _searchStart = 0; _searchStatus.Text = string.Empty; };
        searchBar.Children.Add(_searchBox);

        var find = CreateButton("Find Next");
        find.Click += (_, _) => FindNext();
        Grid.SetColumn(find, 1);
        searchBar.Children.Add(find);

        var decision = CreateButton("Jump to Decision");
        decision.Click += (_, _) => JumpTo("DECISION");
        Grid.SetColumn(decision, 2);
        searchBar.Children.Add(decision);

        var evidence = CreateButton("Jump to Evidence");
        evidence.Click += (_, _) => JumpTo("EVIDENCE");
        Grid.SetColumn(evidence, 3);
        searchBar.Children.Add(evidence);

        _searchStatus = new TextBlock
        {
            Foreground = new SolidColorBrush(Color.FromRgb(149, 165, 186)),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(10, 0, 0, 0),
            MinWidth = 90
        };
        Grid.SetColumn(_searchStatus, 4);
        searchBar.Children.Add(_searchStatus);
        Grid.SetRow(searchBar, 1);
        grid.Children.Add(searchBar);

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
        Grid.SetRow(_textBox, 2);
        grid.Children.Add(_textBox);

        var footer = new Grid { Margin = new Thickness(0, 12, 0, 0) };
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var hint = new TextBlock
        {
            Text = "Ctrl+F focuses search • Enter finds next • Ctrl+C copies selected evidence",
            Foreground = new SolidColorBrush(Color.FromRgb(113, 131, 154)),
            VerticalAlignment = VerticalAlignment.Center
        };
        footer.Children.Add(hint);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        var wrap = CreateButton("Toggle Wrap");
        wrap.Click += (_, _) => _textBox.TextWrapping = _textBox.TextWrapping == TextWrapping.NoWrap ? TextWrapping.Wrap : TextWrapping.NoWrap;
        var copy = CreateButton("Copy All");
        copy.Click += (_, _) => Clipboard.SetText(_textBox.Text);
        var save = CreateButton("Save As…");
        save.Click += (_, _) => SaveReport();
        var close = CreateButton("Close");
        close.Click += (_, _) => Close();
        buttons.Children.Add(wrap);
        buttons.Children.Add(copy);
        buttons.Children.Add(save);
        buttons.Children.Add(close);
        Grid.SetColumn(buttons, 1);
        footer.Children.Add(buttons);
        Grid.SetRow(footer, 3);
        grid.Children.Add(footer);

        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.F && Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
            {
                _searchBox.Focus();
                _searchBox.SelectAll();
                e.Handled = true;
            }
        };

        Content = grid;
    }

    private static Button CreateButton(string content) => new()
    {
        Content = content,
        Padding = new Thickness(14, 7, 14, 7),
        Margin = new Thickness(4, 0, 0, 0)
    };

    private void FindNext()
    {
        var term = _searchBox.Text.Trim();
        if (term.Length == 0) { _searchStatus.Text = "Enter text"; return; }
        var index = _textBox.Text.IndexOf(term, _searchStart, StringComparison.OrdinalIgnoreCase);
        if (index < 0 && _searchStart > 0)
        {
            _searchStart = 0;
            index = _textBox.Text.IndexOf(term, StringComparison.OrdinalIgnoreCase);
        }
        if (index < 0) { _searchStatus.Text = "Not found"; return; }
        _textBox.Focus();
        _textBox.Select(index, term.Length);
        _textBox.ScrollToLine(_textBox.GetLineIndexFromCharacterIndex(index));
        _searchStart = index + term.Length;
        _searchStatus.Text = "Found";
    }

    private void JumpTo(string heading)
    {
        var index = _textBox.Text.IndexOf(heading, StringComparison.OrdinalIgnoreCase);
        if (index < 0) { _searchStatus.Text = $"No {heading.ToLowerInvariant()} section"; return; }
        _textBox.Focus();
        _textBox.Select(index, heading.Length);
        _textBox.ScrollToLine(_textBox.GetLineIndexFromCharacterIndex(index));
        _searchStatus.Text = heading;
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
