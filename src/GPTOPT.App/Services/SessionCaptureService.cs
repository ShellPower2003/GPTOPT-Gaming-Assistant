namespace GPTOPT.App.Services;

public sealed class SessionCaptureService
{
    private static readonly string[] FrameTimeHeaders =
    [
        "MsBetweenPresents", "Frametime", "FrameTime", "Frame Time", "FrameTimeMs", "msBetweenPresents"
    ];

    public IReadOnlyList<string> FindRecentCaptures(int limit = 10)
    {
        var roots = GetCandidateRoots()
            .Where(Directory.Exists)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var files = new List<FileInfo>();
        foreach (var root in roots)
        {
            try
            {
                files.AddRange(Directory.EnumerateFiles(root, "*.csv", SearchOption.AllDirectories)
                    .Select(path => new FileInfo(path))
                    .Where(file => file.Length > 256 && file.LastWriteTimeUtc >= DateTime.UtcNow.AddDays(-30))
                    .Where(file => IsLikelyPerformanceCsv(file.FullName)));
            }
            catch (UnauthorizedAccessException) { }
            catch (IOException) { }
        }

        return files
            .GroupBy(file => file.FullName, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderByDescending(file => file.LastWriteTimeUtc)
            .Take(Math.Max(2, limit))
            .Select(file => file.FullName)
            .ToArray();
    }

    public (string Latest, string? Previous) FindLatestPair()
    {
        var captures = FindRecentCaptures(20);
        if (captures.Count == 0)
            throw new FileNotFoundException(
                "No recent readable CapFrameX or PresentMon CSV capture was found. GPTOPT ignores unrelated CSV files and captures without a supported frame-time column.");

        var latest = captures[0];
        var previous = captures.Skip(1).FirstOrDefault(path => LooksEquivalent(latest, path));
        return (latest, previous);
    }

    public string BuildDiscoveryReport()
    {
        var captures = FindRecentCaptures(10);
        if (captures.Count == 0)
            return "GPTOPT SESSION CAPTURE DISCOVERY\n\nNo recent readable performance CSVs were found. GPTOPT searched known CapFrameX, PresentMon, Documents, Downloads, and Desktop locations and rejected unrelated CSV files.";

        var lines = new List<string>
        {
            "GPTOPT SESSION CAPTURE DISCOVERY",
            string.Empty,
            $"Found {captures.Count} readable performance capture(s):"
        };
        lines.AddRange(captures.Select((path, index) =>
            $"{index + 1}. {Path.GetFileName(path)}\n   {new FileInfo(path).LastWriteTime}\n   {path}"));
        return string.Join("\n", lines);
    }

    private static bool IsLikelyPerformanceCsv(string path)
    {
        try
        {
            using var reader = new StreamReader(path);
            var header = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(header)) return false;
            var separator = header.Contains(';') ? ';' : ',';
            var headers = ParseCsvLine(header, separator);
            return headers.Any(value => FrameTimeHeaders.Any(candidate =>
                value.Contains(candidate, StringComparison.OrdinalIgnoreCase)));
        }
        catch (IOException) { return false; }
        catch (UnauthorizedAccessException) { return false; }
    }

    private static bool LooksEquivalent(string latest, string candidate)
    {
        static string Normalize(string path)
        {
            var name = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
            foreach (var token in new[] { "before", "after", "baseline", "test", "capture", "presentmon", "capframex" })
                name = name.Replace(token, string.Empty, StringComparison.OrdinalIgnoreCase);
            return new string(name.Where(char.IsLetter).ToArray());
        }

        var a = Normalize(latest);
        var b = Normalize(candidate);
        if (a.Length < 4 || b.Length < 4) return false;

        var aHalo = a.Contains("halo", StringComparison.OrdinalIgnoreCase);
        var bHalo = b.Contains("halo", StringComparison.OrdinalIgnoreCase);
        if (aHalo != bHalo) return false;

        var commonLength = Math.Min(Math.Min(a.Length, b.Length), 18);
        return a[..commonLength].Equals(b[..commonLength], StringComparison.OrdinalIgnoreCase)
            || a.Contains(b, StringComparison.OrdinalIgnoreCase)
            || b.Contains(a, StringComparison.OrdinalIgnoreCase);
    }

    private static string[] ParseCsvLine(string line, char separator)
    {
        var values = new List<string>();
        var current = new System.Text.StringBuilder();
        var quoted = false;
        for (var i = 0; i < line.Length; i++)
        {
            var ch = line[i];
            if (ch == '"')
            {
                if (quoted && i + 1 < line.Length && line[i + 1] == '"')
                {
                    current.Append('"');
                    i++;
                }
                else quoted = !quoted;
            }
            else if (ch == separator && !quoted)
            {
                values.Add(current.ToString().Trim());
                current.Clear();
            }
            else current.Append(ch);
        }
        values.Add(current.ToString().Trim());
        return values.ToArray();
    }

    private static IEnumerable<string> GetCandidateRoots()
    {
        var user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);

        yield return Path.Combine(documents, "CapFrameX", "Captures");
        yield return Path.Combine(documents, "CapFrameX");
        yield return Path.Combine(user, "Documents", "CapFrameX", "Captures");
        yield return Path.Combine(user, "Documents", "CapFrameX");
        yield return Path.Combine(local, "CapFrameX", "Captures");
        yield return Path.Combine(local, "Intel", "PresentMon");
        yield return Path.Combine(user, "Downloads");
        yield return desktop;
    }
}
