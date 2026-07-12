using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class RecommendationService
{
    public IReadOnlyList<OptimizationRecommendation> Build(AuditReport report)
    {
        var items = new List<OptimizationRecommendation>();

        AddRegistryControl(items, "game-mode", "Windows Gaming", "Game Mode",
            report.Gaming.GameMode, "1",
            "Game Mode prioritizes the active game and reduces interference from some background activity.",
            "Sets HKCU\\Software\\Microsoft\\GameBar\\AllowAutoGameMode to 1.",
            "Small consistency improvement", false, false, "Low");

        AddRegistryControl(items, "game-dvr", "Windows Gaming", "Game DVR background capture",
            report.Gaming.GameDvr, "0",
            "Background capture can consume GPU, CPU and storage resources when recording is not needed.",
            "Sets HKCU\\System\\GameConfigStore\\GameDVR_Enabled to 0.",
            "Small overhead reduction", false, false, "Low");

        AddRegistryControl(items, "hags", "Graphics", "Hardware-accelerated GPU scheduling",
            report.Gaming.Hags, "2",
            "HAGS moves portions of GPU scheduling into dedicated GPU hardware. It is a reasonable modern baseline on current NVIDIA hardware, but its effect must be verified with frame-time data.",
            "Sets HKLM\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers\\HwSchMode to 2.",
            "Potential frame-pacing improvement", true, true, "Low");

        AddRegistryControl(items, "mpo", "Graphics", "MPO compatibility override",
            report.Gaming.MpoOverride, "5",
            "The MPO override can resolve flicker or presentation-path instability on affected systems. It is not a universal performance enhancement and should remain a symptom-driven choice.",
            "Sets HKLM\\SOFTWARE\\Microsoft\\Windows\\Dwm\\OverlayTestMode to 5.",
            "Compatibility or stability improvement", true, true, "Medium");

        if (report.Health.PendingRebootCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "pending-reboot", Category = "Health", Title = "Complete pending Windows servicing",
                CurrentState = $"{report.Health.PendingRebootCount} pending reboot indicator(s)", TargetState = "No pending reboot indicators",
                Why = "Drivers, Windows components and registry changes may not be fully active until Windows completes the pending reboot.",
                How = "Save work and restart Windows normally. GPTOPT does not force a reboot or close applications.",
                ExpectedImpact = "Configuration consistency", Risk = "Read-only", RequiresReboot = true, CanApply = false
            });
        }

        if (report.Health.ProblemDeviceCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "problem-device", Category = "Devices", Title = "Identify the problem device before changing drivers",
                CurrentState = $"{report.Health.ProblemDeviceCount} device(s) reporting a problem", TargetState = "No relevant device errors",
                Why = "A failed or partially configured device can cause retries, disconnects, DPC activity or missing functionality. The exact device and problem code matter more than the count.",
                How = "Run Targeted Diagnostics or open Device Manager. GPTOPT will not bulk-update drivers.",
                ExpectedImpact = "Potential stability improvement", Risk = "Read-only", CanApply = false
            });
        }

        if (!report.Devices.FlydigiDetected)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "flydigi", Category = "Devices", Title = "Verify the Flydigi controller path",
                CurrentState = "Flydigi/Vader not detected", TargetState = "Controller and GameControllerService detected",
                Why = "The wired controller path and Flydigi service must remain present for consistent input and app-side tuning.",
                How = "Connect the controller by USB, keep Flydigi SpaceStation running, and confirm GameControllerService is active.",
                ExpectedImpact = "Input reliability", Risk = "Read-only", CanApply = false
            });
        }

        if (report.Health.SystemErrorCount > 0 || report.Health.ApplicationErrorCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "event-analysis", Category = "Health", Title = "Classify recent Windows errors",
                CurrentState = $"{report.Health.SystemErrorCount} system and {report.Health.ApplicationErrorCount} application errors in 72 hours",
                TargetState = "Benign events separated from recurring actionable faults",
                Why = "Raw event counts are not a performance metric. Provider, event ID, affected process and recurrence determine whether an error matters for gaming.",
                How = "Use Run Targeted Diagnostics to group WHEA, display-driver, storage, USB, and application crash events.",
                ExpectedImpact = "Root-cause visibility", Risk = "Read-only", CanApply = false
            });
        }

        return items;
    }

    private static void AddRegistryControl(List<OptimizationRecommendation> items, string id, string category,
        string title, string current, string target, string why, string how, string impact, bool admin, bool reboot, string risk)
    {
        var configured = string.Equals(current, target, StringComparison.OrdinalIgnoreCase);
        items.Add(new OptimizationRecommendation
        {
            Id = id,
            Category = category,
            Title = configured ? $"{title} — currently configured" : $"{title} — change recommended",
            CurrentState = string.IsNullOrWhiteSpace(current) ? "Not set" : current,
            TargetState = target,
            Why = configured
                ? $"This setting is already at GPTOPT's current baseline. You can leave it alone or re-apply it if another program changed it outside the audit. {why}"
                : why,
            How = how,
            ExpectedImpact = configured ? "Baseline already active" : impact,
            Risk = risk,
            RequiresAdmin = admin,
            RequiresReboot = reboot,
            CanApply = true,
            IsSelected = !configured && id is "game-mode" or "game-dvr"
        });
    }
}
