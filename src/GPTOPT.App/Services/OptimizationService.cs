using System.Diagnostics;
using System.Text.Json;
using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class OptimizationService
{
    private readonly string _stateRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GPTOPT", "State");

    public async Task<string> ApplyAsync(IEnumerable<OptimizationRecommendation> selected, IProgress<string>? status = null)
    {
        var actions = selected.Where(x => x.IsSelected && x.CanApply).ToArray();
        if (actions.Length == 0) return "No applicable recommendations selected.";

        Directory.CreateDirectory(_stateRoot);
        var snapshotPath = Path.Combine(_stateRoot, $"rollback-{DateTime.Now:yyyyMMdd_HHmmss}.json");
        var snapshot = new Dictionary<string, string?>();

        foreach (var item in actions)
        {
            status?.Report($"Preparing: {item.Title}");
            switch (item.Id)
            {
                case "game-mode":
                    snapshot[item.Id] = await ReadRegistryAsync("HKCU:\\Software\\Microsoft\\GameBar", "AllowAutoGameMode");
                    await RunPowerShellAsync("New-Item -Path 'HKCU:\\Software\\Microsoft\\GameBar' -Force | Out-Null; Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\GameBar' -Name AllowAutoGameMode -Type DWord -Value 1");
                    break;
                case "game-dvr":
                    snapshot[item.Id] = await ReadRegistryAsync("HKCU:\\System\\GameConfigStore", "GameDVR_Enabled");
                    await RunPowerShellAsync("New-Item -Path 'HKCU:\\System\\GameConfigStore' -Force | Out-Null; Set-ItemProperty -Path 'HKCU:\\System\\GameConfigStore' -Name GameDVR_Enabled -Type DWord -Value 0");
                    break;
                case "hags":
                    snapshot[item.Id] = await ReadRegistryAsync("HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers", "HwSchMode");
                    await RunElevatedPowerShellAsync("Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers' -Name HwSchMode -Type DWord -Value 2");
                    break;
                case "mpo":
                    snapshot[item.Id] = await ReadRegistryAsync("HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm", "OverlayTestMode");
                    await RunElevatedPowerShellAsync("New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm' -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm' -Name OverlayTestMode -Type DWord -Value 5");
                    break;
            }
            status?.Report($"Applied: {item.Title}");
        }

        await File.WriteAllTextAsync(snapshotPath, JsonSerializer.Serialize(snapshot, new JsonSerializerOptions { WriteIndented = true }));
        return $"Applied {actions.Length} selected action(s). Rollback snapshot: {snapshotPath}";
    }

    private static async Task<string?> ReadRegistryAsync(string path, string name)
    {
        var command = $"$v=(Get-ItemProperty -LiteralPath '{path}' -Name '{name}' -ErrorAction SilentlyContinue).'{name}'; if($null -ne $v){{$v}}";
        return (await RunPowerShellCaptureAsync(command)).Trim() is { Length: > 0 } value ? value : null;
    }

    private static Task RunPowerShellAsync(string command) => RunProcessAsync(new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -Command \"{command.Replace("\"", "`\"")}\"")
    {
        UseShellExecute = false,
        CreateNoWindow = true
    });

    private static Task RunElevatedPowerShellAsync(string command) => RunProcessAsync(new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -Command \"{command.Replace("\"", "`\"")}\"")
    {
        UseShellExecute = true,
        Verb = "runas"
    });

    private static async Task<string> RunPowerShellCaptureAsync(string command)
    {
        var start = new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -Command \"{command.Replace("\"", "`\"")}\"")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start PowerShell.");
        var output = await process.StandardOutput.ReadToEndAsync();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0) throw new InvalidOperationException(error);
        return output;
    }

    private static async Task RunProcessAsync(ProcessStartInfo start)
    {
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start PowerShell.");
        await process.WaitForExitAsync();
        if (process.ExitCode != 0) throw new InvalidOperationException($"PowerShell exited with code {process.ExitCode}.");
    }
}
