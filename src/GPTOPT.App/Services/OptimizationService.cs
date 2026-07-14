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
        var experimentRoot = Path.Combine(_stateRoot, "Experiments");
        Directory.CreateDirectory(experimentRoot);
        var stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
        var experimentId = $"EXP-{stamp}";
        var snapshotPath = Path.Combine(_stateRoot, $"rollback-{stamp}.json");
        var experimentPath = Path.Combine(experimentRoot, $"{experimentId}.json");
        var snapshot = new Dictionary<string, string?>();

        var experiment = new ExperimentRecord
        {
            ExperimentId = experimentId,
            CreatedUtc = DateTime.UtcNow,
            Status = "APPLYING",
            Hypothesis = BuildHypothesis(actions),
            Actions = actions.Select(x => new ExperimentAction
            {
                Id = x.Id,
                Title = x.Title,
                Category = x.Category,
                Before = x.CurrentState,
                Target = x.TargetState,
                ExpectedImpact = x.ExpectedImpact,
                Risk = x.Risk,
                RequiresReboot = x.RequiresReboot
            }).ToArray(),
            RollbackSnapshot = snapshotPath,
            VerificationInstruction = "Run Verify Changes, then capture the same Halo scene and compare equivalent runs before keeping the experiment."
        };
        await WriteExperimentAsync(experimentPath, experiment);

        try
        {
            foreach (var item in actions)
            {
                status?.Report($"Preparing experiment action: {item.Title}");
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
                    default:
                        throw new InvalidOperationException($"Unsupported experiment action: {item.Id}");
                }
                status?.Report($"Applied experiment action: {item.Title}");
            }

            await File.WriteAllTextAsync(snapshotPath, JsonSerializer.Serialize(snapshot, JsonOptions));
            experiment.Status = actions.Any(x => x.RequiresReboot) ? "APPLIED — REBOOT AND VERIFICATION REQUIRED" : "APPLIED — VERIFICATION REQUIRED";
            experiment.AppliedUtc = DateTime.UtcNow;
            await WriteExperimentAsync(experimentPath, experiment);
            return $"Experiment {experimentId} applied with {actions.Length} action(s). Rollback: {snapshotPath}. Verify before keeping it.";
        }
        catch (Exception ex)
        {
            experiment.Status = "FAILED";
            experiment.Error = ex.Message;
            experiment.CompletedUtc = DateTime.UtcNow;
            await WriteExperimentAsync(experimentPath, experiment);
            throw;
        }
    }

    private static string BuildHypothesis(IReadOnlyCollection<OptimizationRecommendation> actions)
    {
        var impacts = actions.Select(x => x.ExpectedImpact).Where(x => !string.IsNullOrWhiteSpace(x)).Distinct().ToArray();
        return $"Applying {actions.Count} reviewed setting(s) should improve {string.Join(", ", impacts)} without worsening 1% low FPS, P99 frame time, hitch rate, controller stability, or network quality.";
    }

    private static Task WriteExperimentAsync(string path, ExperimentRecord experiment) =>
        File.WriteAllTextAsync(path, JsonSerializer.Serialize(experiment, JsonOptions));

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

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

    private sealed class ExperimentRecord
    {
        public string ExperimentId { get; set; } = string.Empty;
        public DateTime CreatedUtc { get; set; }
        public DateTime? AppliedUtc { get; set; }
        public DateTime? CompletedUtc { get; set; }
        public string Status { get; set; } = string.Empty;
        public string Hypothesis { get; set; } = string.Empty;
        public ExperimentAction[] Actions { get; set; } = [];
        public string RollbackSnapshot { get; set; } = string.Empty;
        public string VerificationInstruction { get; set; } = string.Empty;
        public string? Error { get; set; }
    }

    private sealed class ExperimentAction
    {
        public string Id { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public string Before { get; set; } = string.Empty;
        public string Target { get; set; } = string.Empty;
        public string ExpectedImpact { get; set; } = string.Empty;
        public string Risk { get; set; } = string.Empty;
        public bool RequiresReboot { get; set; }
    }
}