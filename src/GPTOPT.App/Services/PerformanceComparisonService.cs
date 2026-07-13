using System.Globalization;
using System.Text;

namespace GPTOPT.App.Services;

public sealed class PerformanceComparisonService
{
    public string Analyze(string path)
    {
        var values = ReadFrameTimes(path);
        if (values.Count < 30)
            throw new InvalidDataException("The file must contain at least 30 valid frame-time samples.");

        var summary = Summarize(values);
        var sb = new StringBuilder();
        sb.AppendLine("GPTOPT LATEST SESSION ANALYSIS");
        sb.AppendLine();
        sb.AppendLine($"Capture: {Path.GetFileName(path)}");
        sb.AppendLine($"Frames: {values.Count:N0}");
        sb.AppendLine($"Average FPS: {summary.AverageFps:F1}");
        sb.AppendLine($"1% low FPS: {summary.OnePercentLow:F1}");
        sb.AppendLine($"Mean frame time: {summary.MeanMs:F3} ms");
        sb.AppendLine($"P95 frame time: {summary.P95Ms:F3} ms");
        sb.AppendLine($"P99 frame time: {summary.P99Ms:F3} ms");
        sb.AppendLine($"Frame-time standard deviation: {summary.StdDevMs:F3} ms");
        sb.AppendLine();
        sb.AppendLine("INTERPRETATION");
        sb.AppendLine(summary.P99Ms <= summary.MeanMs * 1.6
            ? "Frame-time tail is reasonably controlled relative to the mean."
            : "P99 is elevated relative to the mean; inspect the graph for hitches or scene changes before drawing conclusions.");
        sb.AppendLine(summary.StdDevMs <= summary.MeanMs * 0.35
            ? "Frame-time variance is comparatively tight."
            : "Frame-time variance is broad; repeat the same scene and check background activity, loading, or capture boundaries.");
        sb.AppendLine();
        sb.AppendLine("A single run describes the session but does not prove that a tweak helped. Use an equivalent prior capture for a keep-or-rollback verdict.");
        return sb.ToString();
    }

    public string Compare(string beforePath, string afterPath)
    {
        var before = ReadFrameTimes(beforePath);
        var after = ReadFrameTimes(afterPath);
        if (before.Count < 30 || after.Count < 30)
            throw new InvalidDataException("Each file must contain at least 30 valid frame-time samples.");

        var b = Summarize(before);
        var a = Summarize(after);
        var sb = new StringBuilder();
        sb.AppendLine("GPTOPT BEFORE / AFTER PERFORMANCE COMPARISON");
        sb.AppendLine();
        sb.AppendLine($"Before: {Path.GetFileName(beforePath)} ({before.Count:N0} frames)");
        sb.AppendLine($"After:  {Path.GetFileName(afterPath)} ({after.Count:N0} frames)");
        sb.AppendLine();
        sb.AppendLine($"Average FPS: {b.AverageFps:F1} -> {a.AverageFps:F1} ({DeltaPercent(b.AverageFps, a.AverageFps):+0.0;-0.0;0.0}%)");
        sb.AppendLine($"1% low FPS:  {b.OnePercentLow:F1} -> {a.OnePercentLow:F1} ({DeltaPercent(b.OnePercentLow, a.OnePercentLow):+0.0;-0.0;0.0}%)");
        sb.AppendLine($"Mean frame time: {b.MeanMs:F3} ms -> {a.MeanMs:F3} ms ({DeltaPercent(b.MeanMs, a.MeanMs):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"P95 frame time:  {b.P95Ms:F3} ms -> {a.P95Ms:F3} ms ({DeltaPercent(b.P95Ms, a.P95Ms):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"P99 frame time:  {b.P99Ms:F3} ms -> {a.P99Ms:F3} ms ({DeltaPercent(b.P99Ms, a.P99Ms):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"Std deviation:   {b.StdDevMs:F3} ms -> {a.StdDevMs:F3} ms ({DeltaPercent(b.StdDevMs, a.StdDevMs):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine();

        var score = 0;
        if (a.OnePercentLow > b.OnePercentLow * 1.02) score++;
        if (a.P99Ms < b.P99Ms * 0.98) score++;
        if (a.StdDevMs < b.StdDevMs * 0.98) score++;
        if (a.AverageFps > b.AverageFps * 1.02) score++;
        if (a.OnePercentLow < b.OnePercentLow * 0.98) score--;
        if (a.P99Ms > b.P99Ms * 1.02) score--;
        if (a.StdDevMs > b.StdDevMs * 1.02) score--;

        sb.AppendLine("VERDICT");
        sb.AppendLine(score >= 2
            ? "The after run is meaningfully better across multiple metrics. Keep the change, then repeat once to confirm reproducibility."
            : score <= -2
                ? "The after run is meaningfully worse across multiple metrics. Roll back the change and verify again."
                : "The result is mixed or within normal run-to-run variance. Do not call this an improvement yet; repeat under the same scene and conditions.");
        sb.AppendLine();
        sb.AppendLine("Comparison assumes both captures used the same game scene, cap, resolution, graphics settings, background load, and capture duration.");
        return sb.ToString();
    }

    private static List<double> ReadFrameTimes(string path)
    {
        var lines = File.ReadAllLines(path);
        if (lines.Length < 2) return [];
        var separator = lines[0].Contains(';') ? ';' : ',';
        var headers = Split(lines[0], separator);
        var candidates = new[] { "MsBetweenPresents", "Frametime", "FrameTime", "Frame Time", "FrameTimeMs", "msBetweenPresents" };
        var index = Array.FindIndex(headers, h => candidates.Any(c => h.Contains(c, StringComparison.OrdinalIgnoreCase)));
        if (index < 0) throw new InvalidDataException("Could not find a frame-time column. Supported names include MsBetweenPresents, Frametime, FrameTime, or FrameTimeMs.");

        var values = new List<double>();
        foreach (var line in lines.Skip(1))
        {
            var fields = Split(line, separator);
            if (fields.Length <= index) continue;
            var raw = fields[index].Trim().Trim('"');
            if (double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var value) && value > 0 && value < 1000)
                values.Add(value);
        }
        return values;
    }

    private static string[] Split(string line, char separator) => line.Split(separator);

    private static Summary Summarize(List<double> values)
    {
        var sorted = values.OrderBy(x => x).ToArray();
        var mean = values.Average();
        var variance = values.Sum(x => Math.Pow(x - mean, 2)) / values.Count;
        var p95 = Percentile(sorted, 0.95);
        var p99 = Percentile(sorted, 0.99);
        var worstOnePercent = sorted.Skip((int)Math.Floor(sorted.Length * 0.99)).ToArray();
        var onePercentLow = 1000.0 / worstOnePercent.Average();
        return new Summary(1000.0 / mean, onePercentLow, mean, p95, p99, Math.Sqrt(variance));
    }

    private static double Percentile(double[] sorted, double p)
    {
        var position = (sorted.Length - 1) * p;
        var lower = (int)Math.Floor(position);
        var upper = (int)Math.Ceiling(position);
        if (lower == upper) return sorted[lower];
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
    }

    private static double DeltaPercent(double before, double after) => before == 0 ? 0 : ((after - before) / before) * 100.0;

    private sealed record Summary(double AverageFps, double OnePercentLow, double MeanMs, double P95Ms, double P99Ms, double StdDevMs);
}
