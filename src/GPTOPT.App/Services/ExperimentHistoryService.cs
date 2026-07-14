using System.Text;
using System.Text.Json;

namespace GPTOPT.App.Services;

public sealed class ExperimentHistoryService
{
    private readonly string _root = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GPTOPT", "State", "Experiments");

    public string BuildReport()
    {
        var report = new StringBuilder();
        report.AppendLine("GPTOPT EXPERIMENT LEDGER");
        report.AppendLine($"Generated: {DateTime.Now:F}");
        report.AppendLine();

        if (!Directory.Exists(_root))
        {
            report.AppendLine("No experiments have been recorded yet.");
            report.AppendLine("Apply a reviewed setting through Advanced Tune. GPTOPT will create a hypothesis, rollback snapshot, and verification requirement.");
            return report.ToString();
        }

        var files = Directory.EnumerateFiles(_root, "EXP-*.json")
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .Take(30)
            .ToArray();
        if (files.Length == 0)
        {
            report.AppendLine("No experiment records were found.");
            return report.ToString();
        }

        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var entries = new List<string>();
        foreach (var file in files)
        {
            try
            {
                using var document = JsonDocument.Parse(File.ReadAllText(file));
                var root = document.RootElement;
                var status = Read(root, "Status", "UNKNOWN");
                counts[status] = counts.GetValueOrDefault(status) + 1;
                var entry = new StringBuilder();
                entry.AppendLine(Read(root, "ExperimentId", Path.GetFileNameWithoutExtension(file)));
                entry.AppendLine($"Status: {status}");
                entry.AppendLine($"Created UTC: {Read(root, "CreatedUtc", "unknown")}");
                entry.AppendLine($"Applied UTC: {Read(root, "AppliedUtc", "not applied")}");
                entry.AppendLine($"Hypothesis: {Read(root, "Hypothesis", "not supplied")}");
                entry.AppendLine($"Rollback: {Read(root, "RollbackSnapshot", "not supplied")}");
                entry.AppendLine($"Verification: {Read(root, "VerificationInstruction", "not supplied")}");
                var error = Read(root, "Error", string.Empty);
                if (!string.IsNullOrWhiteSpace(error)) entry.AppendLine($"Failure: {error}");
                entry.AppendLine("Actions:");
                if (root.TryGetProperty("Actions", out var actions) && actions.ValueKind == JsonValueKind.Array)
                {
                    foreach (var action in actions.EnumerateArray())
                    {
                        entry.AppendLine($"• {Read(action, "Title", Read(action, "Id", "unknown action"))}");
                        entry.AppendLine($"  Before: {Read(action, "Before", "unknown")}");
                        entry.AppendLine($"  Target: {Read(action, "Target", "unknown")}");
                        entry.AppendLine($"  Expected impact: {Read(action, "ExpectedImpact", "not supplied")}");
                        entry.AppendLine($"  Risk: {Read(action, "Risk", "not supplied")}; reboot: {Read(action, "RequiresReboot", "false")}");
                    }
                }
                entries.Add(entry.ToString().TrimEnd());
            }
            catch (Exception ex)
            {
                entries.Add($"{Path.GetFileName(file)}\nStatus: UNREADABLE\nFailure: {ex.Message}");
                counts["UNREADABLE"] = counts.GetValueOrDefault("UNREADABLE") + 1;
            }
        }

        report.AppendLine("SUMMARY");
        foreach (var pair in counts.OrderBy(x => x.Key)) report.AppendLine($"• {pair.Key}: {pair.Value}");
        report.AppendLine();
        report.AppendLine("DECISION RULE");
        report.AppendLine("An applied experiment is not complete until the system is re-audited and equivalent Halo captures support KEEP or ROLLBACK. 'Applied' is not the same as 'improved'.");
        report.AppendLine();
        report.AppendLine("EXPERIMENTS");
        report.AppendLine(string.Join("\n\n------------------------------------------------------------\n\n", entries));
        return report.ToString();
    }

    private static string Read(JsonElement element, string name, string fallback)
    {
        if (!element.TryGetProperty(name, out var value) || value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined) return fallback;
        var text = value.ToString();
        return string.IsNullOrWhiteSpace(text) ? fallback : text;
    }
}