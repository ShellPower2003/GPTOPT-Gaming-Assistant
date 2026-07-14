namespace GPTOPT.App.Services;

public sealed class SessionCaptureService
{
    private static readonly string[] FrameTimeHeaders =
    [
        "MsBetweenPresents", "Frametime", "FrameTime", "Frame Time", "FrameTimeMs", "msBetweenPresents"
    ];

    public IReadOnlyList<string> FindRecentCaptures(int limit = 10)
    {
        var files = new List<FileInfo>();
        foreach (var root in GetCandidateRoots().Where(x => Directory.Exists(x.Path)).DistinctBy(x => x.Path, StringComparer.OrdinalIgnoreCase))
        {
            foreach (var path in EnumerateCsvFiles(root.Path, root.Recursive))
            {
                try
                {
                    var file = new FileInfo(path);
                    if (file.Length <= 256 || file.LastWriteTimeUtc < DateTime.UtcNow.AddDays(-30)) continue;
                    if (IsLikelyPerformanceCsv(file.FullName)) files.Add(file);
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        return files
            .GroupBy(file => file.FullName, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderByDescending(CapturePriority)
            .ThenByDescending(file => file.LastWriteTimeUtc)
            .Take(Math.Max(2, limit))
            .Select(file => file.FullName)
            .ToArray();
    }

    public (string Latest, string? Previous) FindLatestPair()
    {
        var captures = FindRecentCaptures(30);
        if (captures.Count == 0)
            throw new FileNotFoundException(
                "No recent readable CapFrameX or PresentMon CSV capture was found. GPTOPT ignores unrelated CSV files and captures without a supported frame-time column.");

        var latest = captures[0];
        var previous = captures.Skip(1).FirstOrDefault(path => LooksEquivalent(latest, path));
        return (latest, previous);
    }

    public string BuildDiscoveryReport()
    {
        var captures = FindRecentCaptures(15);
        if (captures.Count == 0)
            return "GPTOPT SESSION CAPTURE DISCOVERY\n\nNo recent readable performance CSVs were found. GPTOPT searched known CapFrameX and PresentMon folders plus the top level of Downloads and Desktop, then rejected unrelated CSV files.";

        var pair = FindLatestPair();
        var lines = new List<string>
        {
            "GPTOPT SESSION CAPTURE DISCOVERY",
            string.Empty,
            $"Selected latest: {Path.GetFileName(pair.Latest)}",
            $"Automatic comparison candidate: {(pair.Previous is null ? "None — manual comparison remains available" : Path.GetFileName(pair.Previous))}",
            string.Empty,
            "RANKING POLICY",
            "1. Halo-named captures",
            "2. Known CapFrameX or PresentMon locations",
            "3. Newest write time",
            "Desktop and Downloads are scanned only at the top level to avoid a slow full-profile search.",
            string.Empty,
            $"Found {captures.Count} readable performance capture(s):"
        };
        lines.AddRange(captures.Select((path, index) =>
        {
            var file = new FileInfo(path);
            var halo = Path.GetFileName(path).Contains("halo", StringComparison.OrdinalIgnoreCase) ? "Halo match" : "Generic performance capture";
            var source = IsKnownCaptureFolder(path) ? "Known capture folder" : "Desktop/Downloads fallback";
            return $"{index + 1}. {Path.GetFileName(path)}\n   {file.LastWriteTime}\n   {halo} • {source}\n   {path}";
        }));
        return string.Join("\n", lines);
    }

    private static IEnumerable<string> EnumerateCsvFiles(string root, bool recursive)
    {
        try
        {
            return Directory.EnumerateFiles(root, "*.csv", recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly).ToArray();
        }
        catch (UnauthorizedAccessException) { return []; }
        catch (IOException) { return []; }
    }

    private static int CapturePriority(FileInfo file)
    {
        var score = 0;
        if (file.Name.Contains("halo", StringComparison.OrdinalIgnoreCase)) score += 100;
        if (IsKnownCaptureFolder(file.FullName)) score += 30;
        if (file.Name.Contains("capframex", StringComparison.OrdinalIgnoreCase) || file.Name.Contains("presentmon", StringComparison.OrdinalIgnoreCase)) score += 10;
        return score;
    }

    private static bool IsKnownCaptureFolder(string path) =>
        path.Contains("CapFrameX", StringComparison.OrdinalIgnoreCase) ||
        path.Contains("PresentMon", StringComparison.OrdinalIgnoreCase);

    private static bool IsLikelyPerformanceCsv(string path)
    {
        try
        {
            using var reader = new StreamReader(path);
            var header = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(header)) return false;
            var separator = header.Contains(';') ? ';' : ',';
            var headers = ParseCsvLine(header, separator);
            return headers.Any(value => FrameTimeHeaders.Any(candidate => value.Contains(candidate, StringComparison.OrdinalIgnoreCase)));
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
                if (quoted && i + 1 < line.Length && line[i + 1] == '"') { current.Append('"'); i++; }
                else quoted = !quoted;
            }
            else if (ch == separator && !quoted) { values.Add(current.ToString().Trim()); current.Clear(); }
            else current.Append(ch);
        }
        values.Add(current.ToString().Trim());
        return values.ToArray();
    }

    private static IEnumerable<CandidateRoot> GetCandidateRoots()
    {
        var user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        yield return new(Path.Combine(documents, "CapFrameX", "Captures"), true);
        yield return new(Path.Combine(documents, "CapFrameX"), true);
        yield return new(Path.Combine(user, "Documents", "CapFrameX", "Captures"), true);
        yield return new(Path.Combine(user, "Documents", "CapFrameX"), true);
        yield return new(Path.Combine(local, "CapFrameX", "Captures"), true);
        yield return new(Path.Combine(local, "Intel", "PresentMon"), true);
        yield return new(Path.Combine(user, "Downloads"), false);
        yield return new(desktop, false);
    }

    private sealed record CandidateRoot(string Path, bool Recursive);
}
