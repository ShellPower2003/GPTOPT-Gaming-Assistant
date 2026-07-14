using System.Globalization;
using System.Text;

namespace GPTOPT.App.Services;

public sealed class SessionTrendService
{
    public string BuildTrendReport(IReadOnlyList<string> capturePaths)
    {
        var sessions = capturePaths
            .Take(8)
            .Select(TryReadSession)
            .Where(x => x is not null)
            .Cast<SessionSummary>()
            .OrderBy(x => x.TimestampUtc)
            .ToArray();

        var report = new StringBuilder();
        report.AppendLine("GPTOPT RECENT SESSION TREND");
        report.AppendLine();

        if (sessions.Length < 2)
        {
            report.AppendLine("Trend unavailable: at least two readable performance captures are required.");
            report.AppendLine("A single run can describe a session but cannot establish a durable direction.");
            return report.ToString();
        }

        var first = sessions[0];
        var last = sessions[^1];
        report.AppendLine($"Readable sessions: {sessions.Length}");
        report.AppendLine($"Range: {first.TimestampUtc.ToLocalTime():g} -> {last.TimestampUtc.ToLocalTime():g}");
        report.AppendLine();
        report.AppendLine("SESSION HISTORY");
        foreach (var session in sessions)
        {
            report.AppendLine($"• {session.TimestampUtc.ToLocalTime():g} | {Path.GetFileName(session.Path)}");
            report.AppendLine($"  Avg {session.AverageFps:F1} FPS | 1% low {session.OnePercentLowFps:F1} FPS | P99 {session.P99Ms:F3} ms | >25 ms {session.Hitch25Percent:F2}%");
        }

        report.AppendLine();
        report.AppendLine("DIRECTION");
        report.AppendLine(DescribeHigher("Average FPS", first.AverageFps, last.AverageFps));
        report.AppendLine(DescribeHigher("1% low FPS", first.OnePercentLowFps, last.OnePercentLowFps));
        report.AppendLine(DescribeLower("P99 frame time", first.P99Ms, last.P99Ms, "ms"));
        report.AppendLine(DescribeLower("Frames above 25 ms", first.Hitch25Percent, last.Hitch25Percent, "%"));

        var recent = sessions.TakeLast(Math.Min(3, sessions.Length)).ToArray();
        var fpsSpread = RelativeSpread(recent.Select(x => x.AverageFps));
        var lowSpread = RelativeSpread(recent.Select(x => x.OnePercentLowFps));
        var p99Spread = RelativeSpread(recent.Select(x => x.P99Ms));
        var consistent = fpsSpread <= 0.04 && lowSpread <= 0.07 && p99Spread <= 0.12;

        report.AppendLine();
        report.AppendLine("REPEATABILITY");
        report.AppendLine(consistent
            ? "Recent sessions are reasonably repeatable. A keep-or-rollback decision has stronger confidence when the scenes and cap were equivalent."
            : "Recent sessions vary materially. Treat apparent gains as provisional and repeat the same scene, cap, and capture duration.");
        report.AppendLine($"Recent spread: average FPS {fpsSpread:P1}; 1% low {lowSpread:P1}; P99 {p99Spread:P1}.");
        report.AppendLine();
        report.AppendLine("Trend is supporting evidence, not proof of causation. Match resolution, graphics settings, frame cap, map/scene, capture duration, and background load before attributing the direction to an experiment.");
        return report.ToString();
    }

    private static SessionSummary? TryReadSession(string path)
    {
        try
        {
            using var reader = new StreamReader(path);
            var headerLine = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(headerLine)) return null;
            var separator = headerLine.Contains(';') ? ';' : ',';
            var headers = ParseCsvLine(headerLine, separator);
            var names = new[] { "MsBetweenPresents", "Frametime", "FrameTime", "Frame Time", "FrameTimeMs", "msBetweenPresents" };
            var index = Array.FindIndex(headers, h => names.Any(name => h.Contains(name, StringComparison.OrdinalIgnoreCase)));
            if (index < 0) return null;

            var values = new List<double>();
            string? line;
            while ((line = reader.ReadLine()) is not null)
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                var fields = ParseCsvLine(line, separator);
                if (fields.Length <= index) continue;
                if (double.TryParse(fields[index].Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var value) && value > 0 && value < 1000)
                    values.Add(value);
            }
            if (values.Count < 300) return null;

            var sorted = values.OrderBy(x => x).ToArray();
            var mean = values.Average();
            var worstOnePercent = sorted.Skip((int)Math.Floor(sorted.Length * 0.99)).ToArray();
            return new SessionSummary(
                path,
                File.GetLastWriteTimeUtc(path),
                1000.0 / mean,
                1000.0 / worstOnePercent.Average(),
                Percentile(sorted, 0.99),
                values.Count(x => x > 25.0) * 100.0 / values.Count);
        }
        catch (IOException) { return null; }
        catch (UnauthorizedAccessException) { return null; }
    }

    private static string DescribeHigher(string name, double first, double last)
    {
        var delta = Delta(first, last);
        return $"• {name}: {first:F1} -> {last:F1} ({delta:+0.0;-0.0;0.0}%). " +
               (delta >= 2 ? "Direction improved." : delta <= -2 ? "Direction regressed." : "Direction is effectively flat.");
    }

    private static string DescribeLower(string name, double first, double last, string unit)
    {
        var delta = Delta(first, last);
        return $"• {name}: {first:F3}{unit} -> {last:F3}{unit} ({delta:+0.0;-0.0;0.0}%). " +
               (delta <= -2 ? "Direction improved." : delta >= 2 ? "Direction regressed." : "Direction is effectively flat.");
    }

    private static double RelativeSpread(IEnumerable<double> source)
    {
        var values = source.ToArray();
        if (values.Length < 2) return 0;
        var average = values.Average();
        return average == 0 ? 0 : (values.Max() - values.Min()) / average;
    }

    private static double Delta(double before, double after) => before == 0 ? 0 : (after - before) / before * 100.0;

    private static double Percentile(double[] sorted, double p)
    {
        var position = (sorted.Length - 1) * p;
        var lower = (int)Math.Floor(position);
        var upper = (int)Math.Ceiling(position);
        if (lower == upper) return sorted[lower];
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
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

    private sealed record SessionSummary(string Path, DateTime TimestampUtc, double AverageFps, double OnePercentLowFps, double P99Ms, double Hitch25Percent);
}