using System.Diagnostics;
using System.Text.Json;

namespace GPTOPT.App.Services;

public sealed class RollbackService
{
    public string StateRoot { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GPTOPT", "State");

    public IReadOnlyList<string> GetSnapshots()
    {
        if (!Directory.Exists(StateRoot)) return [];
        return Directory.EnumerateFiles(StateRoot, "rollback-*.json")
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .ToArray();
    }

    public async Task<string> RestoreAsync(string snapshotPath, IProgress<string>? status = null)
    {
        if (!File.Exists(snapshotPath)) throw new FileNotFoundException("Rollback snapshot not found.", snapshotPath);
        var values = JsonSerializer.Deserialize<Dictionary<string, string?>>(await File.ReadAllTextAsync(snapshotPath))
            ?? throw new InvalidDataException("Rollback snapshot is empty or invalid.");

        var userCommands = new List<string>();
        var adminCommands = new List<string>();
        foreach (var (id, value) in values)
        {
            status?.Report($"Preparing rollback: {id}");
            switch (id)
            {
                case "game-mode": userCommands.Add(SetOrRemove("HKCU:\\Software\\Microsoft\\GameBar", "AllowAutoGameMode", value)); break;
                case "game-dvr": userCommands.Add(SetOrRemove("HKCU:\\System\\GameConfigStore", "GameDVR_Enabled", value)); break;
                case "hags": adminCommands.Add(SetOrRemove("HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers", "HwSchMode", value)); break;
                case "mpo": adminCommands.Add(SetOrRemove("HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm", "OverlayTestMode", value)); break;
            }
        }

        if (userCommands.Count > 0) await RunPowerShellAsync(string.Join(";", userCommands), false);
        if (adminCommands.Count > 0) await RunPowerShellAsync(string.Join(";", adminCommands), true);

        var marker = Path.ChangeExtension(snapshotPath, ".restored.txt");
        await File.WriteAllTextAsync(marker, $"Restored UTC: {DateTime.UtcNow:O}{Environment.NewLine}Source: {snapshotPath}");
        return $"Rollback restored from {Path.GetFileName(snapshotPath)}. Run Verify Changes to confirm the state.";
    }

    private static string SetOrRemove(string path, string name, string? value) => string.IsNullOrWhiteSpace(value)
        ? $"Remove-ItemProperty -LiteralPath '{path}' -Name '{name}' -ErrorAction SilentlyContinue"
        : $"New-Item -Path '{path}' -Force | Out-Null; Set-ItemProperty -LiteralPath '{path}' -Name '{name}' -Type DWord -Value {value}";

    private static async Task RunPowerShellAsync(string command, bool elevated)
    {
        var start = new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -Command \"{command.Replace("\"", "`\"")}\"")
        {
            UseShellExecute = elevated,
            CreateNoWindow = !elevated
        };
        if (elevated) start.Verb = "runas";
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start rollback process.");
        await process.WaitForExitAsync();
        if (process.ExitCode != 0) throw new InvalidOperationException($"Rollback process exited with code {process.ExitCode}.");
    }
}
