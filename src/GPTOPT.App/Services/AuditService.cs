using System.Diagnostics;
using System.Text.Json;
using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class AuditService
{
    private const string Repository = "ShellPower2003/GPTOPT-Gaming-Assistant";

    private readonly string _auditRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GPTOPT", "Audits");

    public string AuditRoot => _auditRoot;

    public async Task<int> RunAuditAsync(bool publish, IProgress<string>? status = null)
    {
        var script = Path.Combine(AppContext.BaseDirectory, "Scripts", "Invoke-GPTOPTAudit.ps1");
        if (!File.Exists(script))
            throw new FileNotFoundException("GPTOPT audit backend was not packaged with the app.", script);

        status?.Report(publish ? "Starting full PC audit before verified publish…" : "Starting full PC audit…");
        var start = new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -File \"{script}\"")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = new Process { StartInfo = start };
        process.OutputDataReceived += (_, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) status?.Report(e.Data); };
        process.ErrorDataReceived += (_, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) status?.Report(e.Data); };
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0) return process.ExitCode;

        if (publish)
        {
            status?.Report("Publishing the current audit to GitHub issue audit-latest…");
            await PublishLatestAuditAsync(status);
        }

        return 0;
    }

    private async Task PublishLatestAuditAsync(IProgress<string>? status)
    {
        var markdownPath = Path.Combine(_auditRoot, "latest", "GPTOPT-SanitizedReport.md");
        var jsonPath = Path.Combine(_auditRoot, "latest", "GPTOPT-SanitizedReport.json");
        if (!File.Exists(markdownPath) || !File.Exists(jsonPath))
            throw new FileNotFoundException("The current sanitized audit was not created, so publishing was stopped.");

        using var auditDocument = JsonDocument.Parse(await File.ReadAllTextAsync(jsonPath));
        var auditId = Read(auditDocument.RootElement, "audit_id");
        var machineKey = Read(auditDocument.RootElement, "machine_key");
        if (string.IsNullOrWhiteSpace(auditId) || string.IsNullOrWhiteSpace(machineKey))
            throw new InvalidDataException("The current audit is missing its audit ID or machine key.");

        var gh = FindGitHubCli();
        await RunProcessCheckedAsync(gh, "auth status --hostname github.com", "GitHub CLI is not authenticated. Run gh auth login.");

        var issueJson = await RunProcessCheckedAsync(
            gh,
            $"issue list --repo {Repository} --state open --label audit-latest --json number,title --limit 20",
            "Unable to query the audit-latest GitHub issue.");

        int? issueNumber = null;
        if (!string.IsNullOrWhiteSpace(issueJson))
        {
            using var issueDocument = JsonDocument.Parse(issueJson);
            foreach (var issue in issueDocument.RootElement.EnumerateArray())
            {
                var title = Read(issue, "title");
                if (title.Contains("Latest PC Audit", StringComparison.OrdinalIgnoreCase))
                {
                    issueNumber = ReadInt(issue, "number");
                    break;
                }
            }
        }

        var titleText = $"[GPTOPT-AUDIT:{machineKey}] Latest PC Audit";
        if (issueNumber is null or 0)
        {
            var createOutput = await RunProcessCheckedAsync(
                gh,
                $"issue create --repo {Repository} --title \"{titleText}\" --label audit-latest --body-file \"{markdownPath}\"",
                "Unable to create the audit-latest GitHub issue.");
            var numberText = createOutput.TrimEnd('/').Split('/').LastOrDefault();
            if (!int.TryParse(numberText, out var createdNumber))
                throw new InvalidOperationException("GitHub created the audit issue, but GPTOPT could not determine its issue number.");
            issueNumber = createdNumber;
        }
        else
        {
            await RunProcessCheckedAsync(
                gh,
                $"issue edit {issueNumber.Value} --repo {Repository} --title \"{titleText}\" --body-file \"{markdownPath}\"",
                "Unable to update the audit-latest GitHub issue.");
        }

        status?.Report($"Verifying GitHub issue #{issueNumber.Value} contains audit {auditId}…");
        var verifiedJson = await RunProcessCheckedAsync(
            gh,
            $"issue view {issueNumber.Value} --repo {Repository} --json body,url",
            "The audit issue was written but could not be read back for verification.");
        using var verifiedDocument = JsonDocument.Parse(verifiedJson);
        var body = Read(verifiedDocument.RootElement, "body");
        var url = Read(verifiedDocument.RootElement, "url");
        if (!body.Contains(auditId, StringComparison.Ordinal))
            throw new InvalidOperationException($"Publish verification failed: GitHub issue #{issueNumber.Value} does not contain {auditId}.");

        status?.Report($"Publish verified: {url}");
    }

    private static string FindGitHubCli()
    {
        var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var folder in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(folder.Trim(), "gh.exe");
            if (File.Exists(candidate)) return candidate;
        }

        var common = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "GitHub CLI", "gh.exe");
        if (File.Exists(common)) return common;
        throw new FileNotFoundException("GitHub CLI (gh.exe) is required for Publish Verified.");
    }

    private static async Task<string> RunProcessCheckedAsync(string fileName, string arguments, string failureMessage)
    {
        var start = new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using var process = Process.Start(start) ?? throw new InvalidOperationException(failureMessage);
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var output = await outputTask;
        var error = await errorTask;
        if (process.ExitCode != 0)
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? failureMessage : $"{failureMessage}\n{error.Trim()}");
        return output;
    }

    public AuditReport? LoadLatest()
    {
        var path = Path.Combine(_auditRoot, "latest", "GPTOPT-SanitizedReport.json");
        if (!File.Exists(path)) return null;

        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var root = document.RootElement;
        var report = new AuditReport
        {
            AuditId = Read(root, "audit_id"),
            CollectedUtc = Read(root, "collected_utc")
        };

        if (root.TryGetProperty("platform", out var platform))
        {
            report.Platform.Windows = Read(platform, "windows");
            report.Platform.Build = Read(platform, "build");
            report.Platform.Bios = Read(platform, "bios");
            report.Platform.Cpu = Read(platform, "cpu");
            report.Platform.Gpu = Read(platform, "gpu");
            report.Platform.Display = Read(platform, "display");
            report.Platform.MemoryGb = ReadDouble(platform, "memory_gb");
        }
        if (root.TryGetProperty("gaming", out var gaming))
        {
            report.Gaming.PowerPlan = Read(gaming, "power_plan");
            report.Gaming.GameMode = Read(gaming, "game_mode");
            report.Gaming.GameDvr = Read(gaming, "game_dvr");
            report.Gaming.Hags = Read(gaming, "hags");
            report.Gaming.MpoOverride = Read(gaming, "mpo_override");
        }
        if (root.TryGetProperty("devices", out var devices))
        {
            report.Devices.FlydigiDetected = ReadBool(devices, "flydigi_detected");
            report.Devices.NvidiaDriver = Read(devices, "nvidia_driver");
            report.Devices.ActiveWiredAdapters = ReadInt(devices, "active_wired_adapters");
            report.Devices.ActiveWifiAdapters = ReadInt(devices, "active_wifi_adapters");
            report.Devices.GptoptProcesses = ReadArray(devices, "gptopt_processes");
        }
        if (root.TryGetProperty("health", out var health))
        {
            report.Health.SystemErrorCount = ReadInt(health, "system_error_count");
            report.Health.ApplicationErrorCount = ReadInt(health, "application_error_count");
            report.Health.ProblemDeviceCount = ReadInt(health, "problem_device_count");
            report.Health.PendingRebootCount = ReadInt(health, "pending_reboot_count");
            report.Health.SystemDriveFreeGb = ReadDouble(health, "system_drive_free_gb");
            report.Health.WheaCount = ReadInt(health, "whea_count");
            report.Health.DisplayResetCount = ReadInt(health, "display_reset_count");
            report.Health.StorageFaultCount = ReadInt(health, "storage_fault_count");
            report.Health.ControllerFaultCount = ReadInt(health, "controller_fault_count");
            report.Health.GamingCrashCount = ReadInt(health, "gaming_crash_count");
            report.Health.BackgroundCrashCount = ReadInt(health, "background_crash_count");
            report.Health.ProblemDeviceNames = ReadArray(health, "problem_device_names");
            report.Health.PendingRebootSources = ReadArray(health, "pending_reboot_sources");
            report.Health.PendingRenameFiles = ReadArray(health, "pending_rename_files");
            report.Health.GamingCrashApps = ReadArray(health, "gaming_crash_apps");
            report.Health.BackgroundCrashApps = ReadArray(health, "background_crash_apps");
        }
        if (root.TryGetProperty("readiness", out var readiness))
        {
            report.Readiness.Score = ReadInt(readiness, "score");
            report.Readiness.Status = Read(readiness, "status");
            report.Readiness.Summary = Read(readiness, "summary");
            report.Readiness.Blockers = ReadArray(readiness, "blockers");
            report.Readiness.Warnings = ReadArray(readiness, "warnings");
            report.Readiness.PassedChecks = ReadArray(readiness, "passed_checks");
        }
        return report;
    }

    public IReadOnlyList<string> GetHistory() => Directory.Exists(_auditRoot)
        ? Directory.EnumerateDirectories(_auditRoot, "GPTOPT-*")
            .OrderByDescending(Path.GetFileName)
            .Select(Path.GetFileName)
            .Where(x => x is not null)
            .Cast<string>()
            .ToArray()
        : [];

    private static string Read(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) ? value.ToString() : string.Empty;
    private static int ReadInt(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.TryGetInt32(out var result) ? result : 0;
    private static double ReadDouble(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.TryGetDouble(out var result) ? result : 0;
    private static bool ReadBool(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
    private static string[] ReadArray(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array
            ? value.EnumerateArray().Select(x => x.ToString()).Where(x => !string.IsNullOrWhiteSpace(x)).ToArray()
            : [];
}
