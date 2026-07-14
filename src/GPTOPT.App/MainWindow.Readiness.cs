using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using GPTOPT.App.Models;

namespace GPTOPT.App;

public partial class MainWindow
{
    private DispatcherTimer? _readinessRefreshTimer;
    private string? _lastReadinessAuditId;

    protected override void OnContentRendered(EventArgs e)
    {
        base.OnContentRendered(e);
        RefreshReadinessPresentation(force: true);
        _readinessRefreshTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _readinessRefreshTimer.Tick += (_, _) => RefreshReadinessPresentation(force: false);
        _readinessRefreshTimer.Start();
    }

    protected override void OnClosed(EventArgs e)
    {
        _readinessRefreshTimer?.Stop();
        base.OnClosed(e);
    }

    private void RefreshReadinessPresentation(bool force)
    {
        var report = _auditService.LoadLatest();
        if (report is null || (!force && report.AuditId == _lastReadinessAuditId)) return;
        _lastReadinessAuditId = report.AuditId;

        var readiness = NormalizeReadiness(report);
        HealthGradeText.Text = readiness.Score.ToString();
        HealthSummaryText.Text = $"{readiness.Status}\n{readiness.Summary}";
        HealthGradeText.Foreground = readiness.Status switch
        {
            "READY" => BrushFrom(88, 217, 157),
            "READY WITH MINOR ISSUES" => BrushFrom(255, 190, 85),
            _ => BrushFrom(255, 113, 123)
        };

        var lines = new List<string>
        {
            $"Verdict: {readiness.Status}",
            $"Gaming-relevant: WHEA {report.Health.WheaCount} • GPU resets {report.Health.DisplayResetCount} • Storage {report.Health.StorageFaultCount} • Confirmed controller/USB {report.Health.ControllerFaultCount} • Gaming crashes {report.Health.GamingCrashCount}"
        };
        if (readiness.Blockers.Length > 0)
        {
            lines.Add("Blocking:");
            lines.AddRange(readiness.Blockers.Select(x => "• " + x));
        }
        if (readiness.Warnings.Length > 0)
        {
            lines.Add("Review:");
            lines.AddRange(readiness.Warnings.Select(x => "• " + x));
        }

        var controllerEvidence = LoadControllerEvidence();
        if (controllerEvidence.Length > 0)
        {
            lines.Add("Controller evidence:");
            lines.AddRange(controllerEvidence.Select(x => "• " + x));
        }

        if (readiness.Blockers.Length == 0 && readiness.Warnings.Length == 0)
            lines.Add("No gaming-relevant issues detected.");
        HealthText.Text = string.Join("\n", lines);

        StatusText.Text = readiness.Status == "NOT READY" ? "Resolve blockers before performance testing" : "Gaming readiness evaluated";
        StatusDetailText.Text = $"{readiness.Status} • Audit {report.AuditId}";
    }

    private string[] LoadControllerEvidence()
    {
        try
        {
            var path = Path.Combine(_auditService.AuditRoot, "latest", "GPTOPT-SanitizedReport.json");
            if (!File.Exists(path)) return [];
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            if (!document.RootElement.TryGetProperty("health", out var health) ||
                !health.TryGetProperty("controller_fault_evidence", out var evidence) ||
                evidence.ValueKind != JsonValueKind.Array) return [];
            return evidence.EnumerateArray()
                .Select(x => x.ToString())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Take(5)
                .ToArray();
        }
        catch
        {
            return [];
        }
    }

    private static ReadinessInfo NormalizeReadiness(AuditReport report)
    {
        if (!string.IsNullOrWhiteSpace(report.Readiness.Status) && report.Readiness.Status != "Unknown")
            return report.Readiness;

        var blockers = new List<string>();
        var warnings = new List<string>();
        if (report.Health.ProblemDeviceCount > 0) blockers.Add($"{report.Health.ProblemDeviceCount} problem device(s)");
        if (report.Health.PendingRebootCount > 0) warnings.Add("Pending reboot source requires review");
        if (!report.Devices.FlydigiDetected) warnings.Add("Flydigi/Vader path not detected");
        var score = Math.Clamp(100 - blockers.Count * 18 - warnings.Count * 4, 0, 100);
        return new ReadinessInfo
        {
            Score = score,
            Status = blockers.Count > 0 ? "NOT READY" : warnings.Count > 0 ? "READY WITH MINOR ISSUES" : "READY",
            Summary = blockers.Count > 0 ? "Resolve blocking findings before benchmarking." : warnings.Count > 0 ? "Safe to play; minor cleanup remains." : "Core gaming checks passed.",
            Blockers = blockers.ToArray(),
            Warnings = warnings.ToArray()
        };
    }

    private static SolidColorBrush BrushFrom(byte r, byte g, byte b) => new(Color.FromRgb(r, g, b));
}
