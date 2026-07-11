using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class RecommendationService
{
    public IReadOnlyList<OptimizationRecommendation> Build(AuditReport report)
    {
        var items = new List<OptimizationRecommendation>();

        AddRegistryRecommendation(items, "game-mode", "Windows", "Enable Game Mode",
            report.Gaming.GameMode, "1",
            "Game Mode prioritizes the active game and reduces interference from some background activity.",
            "Sets HKCU\\Software\\Microsoft\\GameBar\\AllowAutoGameMode to 1.",
            "Small consistency improvement", false, false);

        AddRegistryRecommendation(items, "game-dvr", "Windows", "Disable Game DVR background capture",
            report.Gaming.GameDvr, "0",
            "Background capture can consume GPU, CPU and storage resources even when no recording is needed.",
            "Sets HKCU\\System\\GameConfigStore\\GameDVR_Enabled to 0.",
            "Small latency and overhead reduction", false, false);

        AddRegistryRecommendation(items, "hags", "Graphics", "Enable Hardware-accelerated GPU scheduling",
            report.Gaming.Hags, "2",
            "HAGS moves portions of GPU scheduling into dedicated GPU hardware. On modern NVIDIA hardware it is commonly the preferred baseline, but it should still be benchmarked.",
            "Sets HKLM\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers\\HwSchMode to 2.",
            "Potential frame-pacing improvement", true, true);

        AddRegistryRecommendation(items, "mpo", "Graphics", "Disable Multi-Plane Overlay override",
            report.Gaming.MpoOverride, "5",
            "MPO can contribute to flicker, stutter or presentation issues on some Windows and driver combinations. This is a compatibility choice, not a universal performance win.",
            "Sets HKLM\\SOFTWARE\\Microsoft\\Windows\\Dwm\\OverlayTestMode to 5.",
            "Compatibility/stability improvement", true, true);

        if (report.Health.PendingRebootCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "pending-reboot", Category = "System", Title = "Complete pending Windows servicing",
                CurrentState = $"{report.Health.PendingRebootCount} pending reboot indicator(s)", TargetState = "No pending reboot indicators",
                Why = "Drivers, Windows components and registry changes may not be fully active until Windows completes the pending reboot.",
                How = "Save work and restart Windows normally. GPTOPT does not force a reboot.",
                ExpectedImpact = "Configuration consistency", Risk = "Low", RequiresReboot = true, CanApply = false
            });
        }

        if (report.Health.ProblemDeviceCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "problem-device", Category = "Devices", Title = "Investigate problem device",
                CurrentState = $"{report.Health.ProblemDeviceCount} device(s) reporting a problem", TargetState = "No relevant device errors",
                Why = "A failed or partially configured device can cause retries, disconnects, DPC activity or missing functionality.",
                How = "Open the latest private audit and identify the device class, status and problem code before changing drivers.",
                ExpectedImpact = "Potential stability improvement", Risk = "Diagnostic", CanApply = false
            });
        }

        if (!report.Devices.FlydigiDetected)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "flydigi", Category = "Controller", Title = "Verify Flydigi controller path",
                CurrentState = "Flydigi/Vader not detected", TargetState = "Controller and GameControllerService detected",
                Why = "The controller service and wired device path must be present for consistent input and app-side tuning.",
                How = "Connect the controller by USB, keep Flydigi SpaceStation running, and confirm GameControllerService is active.",
                ExpectedImpact = "Input reliability", Risk = "Diagnostic", CanApply = false
            });
        }

        if (report.Health.SystemErrorCount > 0 || report.Health.ApplicationErrorCount > 0)
        {
            items.Add(new OptimizationRecommendation
            {
                Id = "event-analysis", Category = "Diagnostics", Title = "Classify recent Windows errors",
                CurrentState = $"{report.Health.SystemErrorCount} system and {report.Health.ApplicationErrorCount} application errors in 72 hours",
                TargetState = "Known benign events separated from actionable faults",
                Why = "Counts alone are not useful. Provider, event ID, affected process and recurrence determine whether an error matters for gaming.",
                How = "Run the enhanced diagnostic classifier to group WHEA, display-driver, storage, USB, application crash and service events.",
                ExpectedImpact = "Root-cause visibility", Risk = "Diagnostic", CanApply = false
            });
        }

        return items;
    }

    private static void AddRegistryRecommendation(List<OptimizationRecommendation> items, string id, string category,
        string title, string current, string target, string why, string how, string impact, bool admin, bool reboot)
    {
        var correct = string.Equals(current, target, StringComparison.OrdinalIgnoreCase);
        items.Add(new OptimizationRecommendation
        {
            Id = id, Category = category, Title = title,
            CurrentState = string.IsNullOrWhiteSpace(current) ? "Not set" : current,
            TargetState = target,
            Why = correct ? $"Already configured. {why}" : why,
            How = how,
            ExpectedImpact = correct ? "Already at target" : impact,
            Risk = id == "mpo" ? "Medium" : "Low",
            RequiresAdmin = admin,
            RequiresReboot = reboot,
            CanApply = !correct,
            IsSelected = !correct && id is "game-mode" or "game-dvr"
        });
    }
}
