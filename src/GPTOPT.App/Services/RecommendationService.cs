using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class RecommendationService
{
    public IReadOnlyList<OptimizationRecommendation> Build(AuditReport report)
    {
        var items = new List<OptimizationRecommendation>();

        AddRegistryRecommendation(items, "game-mode", "Windows Gaming", "Enable Game Mode",
            report.Gaming.GameMode, "1",
            "Game Mode prioritizes the active game and reduces interference from some background activity.",
            "Sets HKCU\\Software\\Microsoft\\GameBar\\AllowAutoGameMode to 1.",
            "Small consistency improvement", false, false, "Low");

        AddRegistryRecommendation(items, "game-dvr", "Windows Gaming", "Disable Game DVR background capture",
            report.Gaming.GameDvr, "0",
            "Background capture can consume GPU, CPU and storage resources when recording is not needed.",
            "Sets HKCU\\System\\GameConfigStore\\GameDVR_Enabled to 0.",
            "Small overhead reduction", false, false, "Low");

        AddRegistryRecommendation(items, "hags", "Graphics", "Enable Hardware-accelerated GPU scheduling",
            report.Gaming.Hags, "2",
            "HAGS moves portions of GPU scheduling into dedicated GPU hardware. It is a reasonable modern baseline on current NVIDIA hardware, but its effect must be verified with frame-time data.",
            "Sets HKLM\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers\\HwSchMode to 2.",
            "Potential frame-pacing improvement", true, true, "Low");

        AddRegistryRecommendation(items, "mpo", "Graphics", "Use the MPO compatibility override",
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
                ExpectedImpact = "Configuration consistency", Risk = "Low", RequiresReboot = true, CanApply = false
            });
        }

        if (report.Health.ProblemDeviceCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "problem-device", Category = "Devices", Title = "Identify the problem device before changing drivers",
                CurrentState = $"{report.Health.ProblemDeviceCount} device(s) reporting a problem", TargetState = "No relevant device errors",
                Why = "A failed or partially configured device can cause retries, disconnects, DPC activity or missing functionality. The exact device and problem code matter more than the count.",
                How = "Open Device Manager or the newest private audit, identify the device class and problem code, then choose a targeted repair. GPTOPT will not bulk-update drivers.",
                ExpectedImpact = "Potential stability improvement", Risk = "Diagnostic", CanApply = false
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
                ExpectedImpact = "Input reliability", Risk = "Diagnostic", CanApply = false
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
                How = "Use Event Viewer or the upcoming GPTOPT classifier to group WHEA, display-driver, storage, USB, application crash and service failures.",
                ExpectedImpact = "Root-cause visibility", Risk = "Diagnostic", CanApply = false
            });
        }

        if (items.Count == 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "baseline-clean", Category = "Health", Title = "No configuration changes recommended",
                CurrentState = "Audited gaming baseline is already at target", TargetState = "Preserve current settings and measure performance",
                Why = "Changing already-correct settings adds risk without evidence of a benefit.",
                How = "Move to performance capture and compare frame-time data before introducing any additional tweak.",
                ExpectedImpact = "Avoid unnecessary changes", Risk = "None", CanApply = false
            });
        }

        return items;
    }

    private static void AddRegistryRecommendation(List<OptimizationRecommendation> items, string id, string category,
        string title, string current, string target, string why, string how, string impact, bool admin, bool reboot, string risk)
    {
        if (string.Equals(current, target, StringComparison.OrdinalIgnoreCase)) return;

        items.Add(new OptimizationRecommendation
        {
            Id = id,
            Category = category,
            Title = title,
            CurrentState = string.IsNullOrWhiteSpace(current) ? "Not set" : current,
            TargetState = target,
            Why = why,
            How = how,
            ExpectedImpact = impact,
            Risk = risk,
            RequiresAdmin = admin,
            RequiresReboot = reboot,
            CanApply = true,
            IsSelected = id is "game-mode" or "game-dvr"
        });
    }
}
