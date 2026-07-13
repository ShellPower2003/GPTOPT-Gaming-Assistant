using System.Diagnostics;
using Microsoft.Win32;

namespace GPTOPT.App;

public partial class MainWindow
{
    private void OpenPresentMonRobust_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var existing = Process.GetProcesses()
                .FirstOrDefault(p => p.ProcessName.Contains("PresentMon", StringComparison.OrdinalIgnoreCase));
            if (existing is not null)
            {
                try { existing.MainWindowHandle.ToString(); }
                catch { }
                StatusText.Text = $"PresentMon is already running: {existing.ProcessName}";
                return;
            }

            var checkedPaths = new List<string>();
            var path = FindPresentMon(checkedPaths);
            if (path is null)
            {
                MessageBox.Show(
                    "GPTOPT could not find a launchable PresentMon executable.\n\nChecked:\n" +
                    string.Join("\n", checkedPaths.Distinct(StringComparer.OrdinalIgnoreCase).Take(20)),
                    "PresentMon not found",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            Process.Start(new ProcessStartInfo(path) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(path)! });
            StatusText.Text = $"Launched PresentMon: {Path.GetFileName(path)}";
            StatusDetailText.Text = path;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "GPTOPT PresentMon Launch", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private static string? FindPresentMon(List<string> checkedPaths)
    {
        string[] executableNames = ["IntelPresentMon.exe", "PresentMon.exe"];

        foreach (var name in executableNames)
        {
            try
            {
                using var key = Registry.LocalMachine.OpenSubKey($@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{name}")
                    ?? Registry.CurrentUser.OpenSubKey($@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{name}");
                var value = key?.GetValue(null)?.ToString()?.Trim('"');
                if (!string.IsNullOrWhiteSpace(value))
                {
                    checkedPaths.Add(value);
                    if (File.Exists(value)) return value;
                }
            }
            catch { }
        }

        foreach (var name in executableNames)
        {
            try
            {
                var psi = new ProcessStartInfo("where.exe", name) { RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true };
                using var process = Process.Start(psi);
                var output = process?.StandardOutput.ReadToEnd();
                process?.WaitForExit(2000);
                foreach (var candidate in (output ?? string.Empty).Split(['\r','\n'], StringSplitOptions.RemoveEmptyEntries))
                {
                    checkedPaths.Add(candidate);
                    if (File.Exists(candidate)) return candidate;
                }
            }
            catch { }
        }

        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var pfx86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var candidates = new[]
        {
            Path.Combine(pf, "Intel", "PresentMon", "IntelPresentMon.exe"),
            Path.Combine(pf, "Intel", "PresentMon", "PresentMon.exe"),
            Path.Combine(pf, "PresentMon", "IntelPresentMon.exe"),
            Path.Combine(pf, "PresentMon", "PresentMon.exe"),
            Path.Combine(local, "Programs", "PresentMon", "IntelPresentMon.exe"),
            Path.Combine(local, "Programs", "PresentMon", "PresentMon.exe"),
            Path.Combine(pfx86, "CapFrameX", "PresentMon.exe"),
            Path.Combine(pf, "CapFrameX", "PresentMon.exe")
        };

        foreach (var candidate in candidates)
        {
            checkedPaths.Add(candidate);
            if (File.Exists(candidate)) return candidate;
        }

        return null;
    }
}
