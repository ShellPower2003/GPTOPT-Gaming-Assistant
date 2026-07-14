using System.Globalization;
using System.Text;

namespace GPTOPT.App.Services;

public sealed class PerformanceComparisonService
{
    public string Analyze(string path)
    {
        var values = ReadFrameTimes(path);
        ValidateMinimum(values);
        var summary = Summarize(values);
        var sb = new StringBuilder();
        sb.AppendLine("GPTOPT LATEST SESSION ANALYSIS");
        sb.AppendLine();
        sb.AppendLine("CAPTURE QUALITY");
        sb.AppendLine($"Capture: {Path.GetFileName(path)}");
        sb.AppendLine($"Frames: {values.Count:N0}");
        sb.AppendLine($"Estimated duration: {summary.DurationSeconds:F1} seconds");
        sb.AppendLine($"Quality: {CaptureQuality(summary)}");
        sb.AppendLine();
        AppendMetrics(sb, summary);
        sb.AppendLine();
        sb.AppendLine("HITCH SIGNALS");
        sb.AppendLine($"Frames above 25 ms: {summary.FramesAbove25Ms:N0} ({summary.FramesAbove25MsPercent:F3}%)");
        sb.AppendLine($"Frames above 50 ms: {summary.FramesAbove50Ms:N0} ({summary.FramesAbove50MsPercent:F3}%)");
        sb.AppendLine($"Largest frame time: {summary.MaxMs:F3} ms");
        sb.AppendLine();
        sb.AppendLine("INTERPRETATION");
        sb.AppendLine(summary.P99Ms <= summary.MeanMs * 1.6
            ? "Frame-time tail is reasonably controlled relative to the mean."
            : "P99 is elevated relative to the mean; inspect hitch timestamps and capture boundaries before drawing conclusions.");
        sb.AppendLine(summary.StdDevMs <= summary.MeanMs * 0.35
            ? "Frame-time variance is comparatively tight."
            : "Frame-time variance is broad; repeat the same scene and check loading, background activity, or an inconsistent route.");
        sb.AppendLine(summary.FramesAbove50MsPercent <= 0.05
            ? "Severe hitch incidence is low for this capture."
            : "Severe hitch incidence is elevated; identify whether the spikes align with menus, loading, deaths, respawns, or actual gameplay.");
        sb.AppendLine();
        sb.AppendLine("DECISION");
        sb.AppendLine(summary.DurationSeconds < 30
            ? "INCONCLUSIVE — the capture is too short for a tuning decision. Record at least 60 seconds of repeatable gameplay."
            : "DESCRIPTIVE ONLY — one run can establish a baseline but cannot prove a tweak helped. Compare an equivalent prior run.");
        return sb.ToString();
    }

    public string Compare(string beforePath, string afterPath)
    {
        var before = ReadFrameTimes(beforePath);
        var after = ReadFrameTimes(afterPath);
        ValidateMinimum(before);
        ValidateMinimum(after);
        var b = Summarize(before);
        var a = Summarize(after);
        var durationDelta = Math.Abs(DeltaPercent(b.DurationSeconds, a.DurationSeconds));
        var durationComparable = durationDelta <= 25;

        var sb = new StringBuilder();
        sb.AppendLine("GPTOPT BEFORE / AFTER PERFORMANCE COMPARISON");
        sb.AppendLine();
        sb.AppendLine("COMPARABILITY CHECK");
        sb.AppendLine($"Before: {Path.GetFileName(beforePath)} — {b.DurationSeconds:F1}s, {before.Count:N0} frames");
        sb.AppendLine($"After:  {Path.GetFileName(afterPath)} — {a.DurationSeconds:F1}s, {after.Count:N0} frames");
        sb.AppendLine($"Duration difference: {durationDelta:F1}% — {(durationComparable ? "acceptable" : "too large")}");
        sb.AppendLine($"Confidence: {ComparisonConfidence(b, a, durationComparable)}");
        sb.AppendLine();
        sb.AppendLine("METRIC CHANGES");
        sb.AppendLine($"Average FPS: {b.AverageFps:F1} -> {a.AverageFps:F1} ({DeltaPercent(b.AverageFps, a.AverageFps):+0.0;-0.0;0.0}%)");
        sb.AppendLine($"1% low FPS:  {b.OnePercentLow:F1} -> {a.OnePercentLow:F1} ({DeltaPercent(b.OnePercentLow, a.OnePercentLow):+0.0;-0.0;0.0}%)");
        sb.AppendLine($"Mean frame time: {b.MeanMs:F3} ms -> {a.MeanMs:F3} ms ({DeltaPercent(b.MeanMs, a.MeanMs):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"P95 frame time:  {b.P95Ms:F3} ms -> {a.P95Ms:F3} ms ({DeltaPercent(b.P95Ms, a.P95Ms):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"P99 frame time:  {b.P99Ms:F3} ms -> {a.P99Ms:F3} ms ({DeltaPercent(b.P99Ms, a.P99Ms):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($"Std deviation:   {b.StdDevMs:F3} ms -> {a.StdDevMs:F3} ms ({DeltaPercent(b.StdDevMs, a.StdDevMs):+0.0;-0.0;0.0}%; lower is better)");
        sb.AppendLine($">25 ms frames:   {b.FramesAbove25MsPercent:F3}% -> {a.FramesAbove25MsPercent:F3}%");
        sb.AppendLine($">50 ms frames:   {b.FramesAbove50MsPercent:F3}% -> {a.FramesAbove50MsPercent:F3}%");
        sb.AppendLine();

        if (!durationComparable || b.DurationSeconds < 30 || a.DurationSeconds < 30)
        {
            sb.AppendLine("VERDICT");
            sb.AppendLine("INCONCLUSIVE — captures are too short or materially different in duration. Repeat the same route for at least 60 seconds before keeping or rolling back a change.");
            return sb.ToString();
        }

        var score = 0;
        if (a.OnePercentLow > b.OnePercentLow * 1.02) score++;
        if (a.P99Ms < b.P99Ms * 0.98) score++;
        if (a.StdDevMs < b.StdDevMs * 0.98) score++;
        if (a.AverageFps > b.AverageFps * 1.02) score++;
        if (a.FramesAbove25MsPercent < b.FramesAbove25MsPercent * 0.90) score++;
        if (a.OnePercentLow < b.OnePercentLow * 0.98) score--;
        if (a.P99Ms > b.P99Ms * 1.02) score--;
        if (a.StdDevMs > b.StdDevMs * 1.02) score--;
        if (a.FramesAbove25MsPercent > b.FramesAbove25MsPercent * 1.10) score--;

        sb.AppendLine("VERDICT");
        sb.AppendLine(score >= 3
            ? "KEEP CANDIDATE — the after run is better across several independent metrics. Repeat once more before making the change permanent."
            : score <= -3
                ? "ROLLBACK CANDIDATE — the after run is worse across several independent metrics. Roll back and repeat the baseline route."
                : "INCONCLUSIVE — changes are mixed or within normal run-to-run variance. Do not call this an improvement yet.");
        sb.AppendLine();
        sb.AppendLine("VALIDITY CONDITIONS");
        sb.AppendLine("Both captures must use the same scene, route, FPS cap, resolution, graphics settings, background load, capture tool, and controller state.");
        return sb.ToString();
    }

    private static void AppendMetrics(StringBuilder sb, Summary summary)
    {
        sb.AppendLine("CORE METRICS");
        sb.AppendLine($"Average FPS: {summary.AverageFps:F1}");
        sb.AppendLine($"1% low FPS: {summary.OnePercentLow:F1}");
        sb.AppendLine($"Mean frame time: {summary.MeanMs:F3} ms");
        sb.AppendLine($"P95 frame time: {summary.P95Ms:F3} ms");
        sb.AppendLine($"P99 frame time: {summary.P99Ms:F3} ms");
        sb.AppendLine($"Frame-time standard deviation: {summary.StdDevMs:F3} ms");
    }

    private static string CaptureQuality(Summary summary) => summary.DurationSeconds switch
    {
        < 15 => "Poor — too short to represent a gameplay session",
        < 30 => "Limited — useful for a quick fault check only",
        < 60 => "Fair — acceptable for a repeatable micro-benchmark",
        _ => "Good — long enough for session-level analysis"
    };

    private static string ComparisonConfidence(Summary before, Summary after, bool durationComparable)
    {
        if (!durationComparable || before.DurationSeconds < 30 || after.DurationSeconds < 30) return "LOW";
        if (before.DurationSeconds >= 60 && after.DurationSeconds >= 60) return "MODERATE — still requires the same route and conditions";
        return "LIMITED — repeat once more under the same conditions";
    }

    private static void ValidateMinimum(List<double> values)
    {
        if (values.Count < 30) throw new InvalidDataException("The file must contain at least 30 valid frame-time samples.");
    }

    private static List<double> ReadFrameTimes(string path)
    {
        using var reader = new StreamReader(path);
        var headerLine = reader.ReadLine();
        if (string.IsNullOrWhiteSpace(headerLine)) return [];
        var separator = headerLine.Contains(';') ? ';' : ',';
        var headers = ParseCsvLine(headerLine, separator);
        var candidates = new[] { "MsBetweenPresents", "Frametime", "FrameTime", "Frame Time", "FrameTimeMs", "msBetweenPresents" };
        var index = Array.FindIndex(headers, h => candidates.Any(c => h.Contains(c, StringComparison.OrdinalIgnoreCase)));
        if (index < 0) throw new InvalidDataException("Could not find a frame-time column. Supported names include MsBetweenPresents, Frametime, FrameTime, or FrameTimeMs.");
        var values = new List<double>();
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            var fields = ParseCsvLine(line, separator);
            if (fields.Length <= index) continue;
            if (double.TryParse(fields[index].Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var value) && value > 0 && value < 1000) values.Add(value);
        }
        return values;
    }

    private static string[] ParseCsvLine(string line, char separator)
    {
        var values = new List<string>();
        var current = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < line.Length; i++)
        {
            var ch = line[i];
            if (ch == '"')
            {
                if (quoted && i + 1 < line.Length && line[i + 1] == '"') { current.Append('"'); i++; }
                else quoted = !quoted;
            }
            else if (ch == separator && !quoted) { values.Add(current.ToString()); current.Clear(); }
            else current.Append(ch);
        }
        values.Add(current.ToString());
        return values.ToArray();
    }

    private static Summary Summarize(List<double> values)
    {
        var sorted = values.OrderBy(x => x).ToArray();
        var mean = values.Average();
        var variance = values.Sum(x => Math.Pow(x - mean, 2)) / values.Count;
        var p95 = Percentile(sorted, 0.95);
        var p99 = Percentile(sorted, 0.99);
        var worstOnePercent = sorted.Skip((int)Math.Floor(sorted.Length * 0.99)).ToArray();
        var above25 = values.Count(x => x > 25);
        var above50 = values.Count(x => x > 50);
        return new Summary(
            1000.0 / mean,
            1000.0 / worstOnePercent.Average(),
            mean,
            p95,
            p99,
            Math.Sqrt(variance),
            values.Sum() / 1000.0,
            values.Max(),
            above25,
            above50,
            above25 * 100.0 / values.Count,
            above50 * 100.0 / values.Count);
    }

    private static double Percentile(double[] sorted, double p)
    {
        var position = (sorted.Length - 1) * p;
        var lower = (int)Math.Floor(position);
        var upper = (int)Math.Ceiling(position);
        return lower == upper ? sorted[lower] : sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
    }

    private static double DeltaPercent(double before, double after) => before == 0 ? 0 : ((after - before) / before) * 100.0;

    private sealed record Summary(
        double AverageFps,
        double OnePercentLow,
        double MeanMs,
        double P95Ms,
        double P99Ms,
        double StdDevMs,
        double DurationSeconds,
        double MaxMs,
        int FramesAbove25Ms,
        int FramesAbove50Ms,
        double FramesAbove25MsPercent,
        double FramesAbove50MsPercent);
}
