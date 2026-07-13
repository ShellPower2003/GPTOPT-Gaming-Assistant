namespace GPTOPT.App.Services;

public sealed class SessionCaptureService
{
    private static readonly string[] SupportedExtensions = [".csv"];

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
                files.AddRange(Directory.EnumerateFiles(root, "*.*", SearchOption.AllDirectories)
                    .Where(path => SupportedExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase))
                    .Select(path => new FileInfo(path))
                    .Where(file => file.Length > 256 && file.LastWriteTimeUtc >= DateTime.UtcNow.AddDays(-30)));
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
            throw new FileNotFoundException("No recent CapFrameX or PresentMon CSV capture was found. Record a capture first, then run this again.");

        var latest = captures[0];
        var previous = captures.Skip(1).FirstOrDefault(path => LooksEquivalent(latest, path));
        return (latest, previous);
    }

    public string BuildDiscoveryReport()
    {
        var captures = FindRecentCaptures(10);
        if (captures.Count == 0)
            return "GPTOPT SESSION CAPTURE DISCOVERY\n\nNo recent CSV captures were found in known CapFrameX, PresentMon, Documents, Downloads, or Desktop locations.";

        var lines = new List<string>
        {
            "GPTOPT SESSION CAPTURE DISCOVERY",
            string.Empty,
            $"Found {captures.Count} recent capture(s):"
        };
        lines.AddRange(captures.Select((path, index) => $"{index + 1}. {Path.GetFileName(path)}\n   {new FileInfo(path).LastWriteTime}\n   {path}"));
        return string.Join("\n", lines);
    }

    private static bool LooksEquivalent(string latest, string candidate)
    {
        static string Normalize(string path)
        {
            var name = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
            foreach (var token in new[] { "before", "after", "baseline", "test", "capture" })
                name = name.Replace(token, string.Empty, StringComparison.OrdinalIgnoreCase);
            return new string(name.Where(char.IsLetterOrDigit).ToArray());
        }

        var a = Normalize(latest);
        var b = Normalize(candidate);
        if (a.Length == 0 || b.Length == 0) return true;
        return a.Contains("halo") == b.Contains("halo") || a[..Math.Min(8, a.Length)] == b[..Math.Min(8, b.Length)];
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
