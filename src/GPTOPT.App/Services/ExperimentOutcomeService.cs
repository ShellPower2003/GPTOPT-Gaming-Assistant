using System.Text.Json;

namespace GPTOPT.App.Services;

public sealed class ExperimentOutcomeService
{
    private readonly string _root = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GPTOPT", "State", "Experiments");

    public string? RecordLatestOutcome(string comparisonReport, string beforeCapture, string afterCapture)
    {
        if (!Directory.Exists(_root)) return null;

        var verdict = ExtractVerdict(comparisonReport);
        if (verdict is null) return null;

        var latest = Directory.EnumerateFiles(_root, "EXP-*.json")
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .FirstOrDefault(IsAwaitingVerification);
        if (latest is null) return null;

        using var document = JsonDocument.Parse(File.ReadAllText(latest));
        var root = document.RootElement;
        var values = new Dictionary<string, object?>();
        foreach (var property in root.EnumerateObject())
            values[property.Name] = JsonSerializer.Deserialize<object>(property.Value.GetRawText());

        values["Status"] = verdict;
        values["VerifiedUtc"] = DateTime.UtcNow.ToString("O");
        values["BeforeCapture"] = beforeCapture;
        values["AfterCapture"] = afterCapture;
        values["MeasurementSummary"] = ExtractMeasurementSummary(comparisonReport);
        values["DecisionRule"] = verdict switch
        {
            "KEEP CANDIDATE" => "Repeat once under equivalent conditions before treating the change as proven.",
            "ROLLBACK CANDIDATE" => "Use the recorded rollback snapshot, then re-audit and capture again.",
            _ => "Do not keep or roll back from this evidence alone; repeat equivalent runs."
        };

        File.WriteAllText(latest, JsonSerializer.Serialize(values, new JsonSerializerOptions { WriteIndented = true }));
        return $"Experiment {Path.GetFileNameWithoutExtension(latest)} updated to {verdict}.";
    }

    private static bool IsAwaitingVerification(string path)
    {
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            if (!document.RootElement.TryGetProperty("Status", out var status)) return false;
            var text = status.GetString() ?? string.Empty;
            return text.Contains("VERIFICATION REQUIRED", StringComparison.OrdinalIgnoreCase) ||
                   text.Equals("APPLIED", StringComparison.OrdinalIgnoreCase);
        }
        catch { return false; }
    }

    private static string? ExtractVerdict(string report)
    {
        if (report.Contains("KEEP CANDIDATE", StringComparison.OrdinalIgnoreCase)) return "KEEP CANDIDATE";
        if (report.Contains("ROLLBACK CANDIDATE", StringComparison.OrdinalIgnoreCase)) return "ROLLBACK CANDIDATE";
        if (report.Contains("INCONCLUSIVE", StringComparison.OrdinalIgnoreCase)) return "INCONCLUSIVE";
        return null;
    }

    private static string ExtractMeasurementSummary(string report)
    {
        var useful = report.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Where(line => line.StartsWith("Average FPS", StringComparison.OrdinalIgnoreCase) ||
                           line.StartsWith("1% low", StringComparison.OrdinalIgnoreCase) ||
                           line.StartsWith("P95", StringComparison.OrdinalIgnoreCase) ||
                           line.StartsWith("P99", StringComparison.OrdinalIgnoreCase) ||
                           line.StartsWith("Hitch", StringComparison.OrdinalIgnoreCase) ||
                           line.StartsWith("Comparison confidence", StringComparison.OrdinalIgnoreCase))
            .Take(12);
        return string.Join(Environment.NewLine, useful);
    }
}
