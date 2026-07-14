using GPTOPT.App.Models;

namespace GPTOPT.App.Services;

public sealed class RecommendationService
{
    public IReadOnlyList<OptimizationRecommendation> Build(AuditReport report)
    {
        var items = new List<OptimizationRecommendation>();

        AddRegistryControl(items, "game-mode", "Windows Gaming", "Game Mode", report.Gaming.GameMode, "1",
            "Game Mode prioritizes the active game and reduces interference from some background activity.",
            "Sets HKCU\\Software\\Microsoft\\GameBar\\AllowAutoGameMode to 1.",
            "Small consistency improvement", false, false, "Low");
        AddRegistryControl(items, "game-dvr", "Windows Gaming", "Game DVR background capture", report.Gaming.GameDvr, "0",
            "Background capture can consume GPU, CPU and storage resources when recording is not needed.",
            "Sets HKCU\\System\\GameConfigStore\\GameDVR_Enabled to 0.",
            "Small overhead reduction", false, false, "Low");
        AddRegistryControl(items, "hags", "Graphics", "Hardware-accelerated GPU scheduling", report.Gaming.Hags, "2",
            "HAGS is a reasonable modern baseline on current NVIDIA hardware, but its effect must be verified with frame-time data.",
            "Sets HKLM\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers\\HwSchMode to 2.",
            "Potential frame-pacing improvement", true, true, "Low");
        AddRegistryControl(items, "mpo", "Graphics", "MPO compatibility override", report.Gaming.MpoOverride, "5",
            "The MPO override can resolve flicker or presentation-path instability on affected systems. It is not a universal performance enhancement.",
            "Sets HKLM\\SOFTWARE\\Microsoft\\Windows\\Dwm\\OverlayTestMode to 5.",
            "Compatibility or stability improvement", true, true, "Medium");

        AddEvidenceFindings(items, report);
        return items;
    }

    private static void AddEvidenceFindings(List<OptimizationRecommendation> items, AuditReport report)
    {
        if (report.Health.WheaCount > 0)
            AddFinding(items, "whea", "Health", "Hardware instability requires investigation",
                $"{report.Health.WheaCount} WHEA event(s)", "Zero WHEA events",
                "WHEA can indicate CPU, memory, PCIe, firmware, voltage, or hardware instability.",
                "Open Targeted Diagnostics and Event Viewer. Identify the exact WHEA event and component before changing BIOS, voltage, or drivers.",
                "Blocking stability risk", false);

        if (report.Health.DisplayResetCount > 0)
            AddFinding(items, "gpu-reset", "Health", "GPU/display reset evidence",
                $"{report.Health.DisplayResetCount} reset event(s)", "No display-driver resets",
                "Display or nvlddmkm resets can interrupt gameplay and may indicate driver, power, presentation-path, or GPU stability problems.",
                "Correlate the exact timestamp with Halo, driver changes, overclocking, undervolting, and display behavior.",
                "High gaming impact", false);

        if (report.Health.StorageFaultCount > 0)
            AddFinding(items, "storage", "Health", "Storage timeout or fault evidence",
                $"{report.Health.StorageFaultCount} storage event(s)", "No storage faults",
                "Storage events can cause severe hitching, loading stalls, or application instability.",
                "Review event IDs and the affected device before changing storage drivers or firmware.",
                "High hitching risk", false);

        if (report.Health.ControllerFaultCount > 0)
            AddFinding(items, "controller", "Devices", "Confirmed controller-path events",
                $"{report.Health.ControllerFaultCount} event(s): {Join(report.Health.ControllerFaultEvidence)}", "No confirmed Vader/Xbox/HID path faults",
                "Only events matching the actual controller path are counted. Timing and device identity matter more than the count.",
                "Compare timestamps with gameplay and verify the USB cable, port, GameControllerService, and Flydigi SpaceStation state.",
                "Potential input interruption", false);

        if (report.Health.GamingCrashCount > 0)
            AddFinding(items, "gaming-crash", "Health", "Gaming-related process crashes",
                $"{report.Health.GamingCrashCount} crash(es): {Join(report.Health.GamingCrashApps)}", "No gaming-path crashes",
                "Crashes involving Halo, NVIDIA, capture tools, controller services, or gaming audio can invalidate a session.",
                "Use Targeted Diagnostics to identify the executable and timestamp, then fix that specific process.",
                "Session reliability", false);

        if (report.Health.ProblemDeviceCount > 0)
            AddFinding(items, "problem-device", "Devices", "Active device problem",
                $"{report.Health.ProblemDeviceCount} device(s): {Join(report.Health.ProblemDeviceNames)}", "No active device error codes",
                "A failed or partially configured device can cause retries, disconnects, DPC activity, or missing functionality.",
                "Open Targeted Diagnostics or Device Manager and resolve the named device. GPTOPT will not bulk-update drivers.",
                "Potential stability impact", false);

        if (!report.Devices.FlydigiDetected)
            AddFinding(items, "flydigi", "Devices", "Flydigi controller path not detected",
                "No Vader/Flydigi hardware ID or GameControllerService evidence", "Controller and service detected",
                "The wired controller path and Flydigi service must remain present for consistent input and app-side tuning.",
                "Connect by USB, keep Flydigi SpaceStation running, and confirm GameControllerService is active.",
                "Input reliability", false);

        if (report.Health.PendingRebootCount > 0)
        {
            var staleOnly = report.Health.PendingRebootSources.Length == 1 &&
                report.Health.PendingRenameFiles.Any(x => x.Equals("gamingservicesproxy_11.dll.0", StringComparison.OrdinalIgnoreCase));
            AddFinding(items, "pending-reboot", "Health", staleOnly ? "Stale Gaming Services cleanup entry" : "Windows servicing is incomplete",
                $"Sources: {Join(report.Health.PendingRebootSources)}; files: {Join(report.Health.PendingRenameFiles)}", "No pending reboot sources",
                staleOnly ? "This isolated Gaming Services rename entry is informational unless Gaming Services is malfunctioning." : "Drivers or Windows components may not be fully active until servicing completes.",
                staleOnly ? "Reboot when convenient, then re-scan. Do not block Steam Halo on this entry alone." : "Save work, restart Windows normally, and run Verify Changes. GPTOPT never forces a reboot.",
                staleOnly ? "Minimal gaming impact" : "Configuration consistency", true);
        }

        if (report.Health.BackgroundCrashCount > 0)
            AddFinding(items, "background-crashes", "Health", "Background crashes retained for context",
                $"{report.Health.BackgroundCrashCount} non-gaming crash(es): {Join(report.Health.BackgroundCrashApps)}", "No recurring background crash pattern",
                "These events stay visible but do not reduce gaming readiness unless they correlate with Halo, input, graphics, audio, or capture failures.",
                "Ignore isolated unrelated crashes. Investigate repeated failures or symptoms overlapping a gaming session.",
                "Informational", false);
    }

    private static void AddFinding(List<OptimizationRecommendation> items, string id, string category, string title,
        string current, string target, string why, string how, string impact, bool requiresReboot)
    {
        items.Add(new OptimizationRecommendation
        {
            Id = id, Category = category, Title = title, CurrentState = current, TargetState = target,
            Why = why, How = how, ExpectedImpact = impact, Risk = "Read-only",
            RequiresReboot = requiresReboot, CanApply = false
        });
    }

    private static string Join(IEnumerable<string> values)
    {
        var items = values.Where(x => !string.IsNullOrWhiteSpace(x)).ToArray();
        return items.Length == 0 ? "none supplied" : string.Join("; ", items);
    }

    private static void AddRegistryControl(List<OptimizationRecommendation> items, string id, string category,
        string title, string current, string target, string why, string how, string impact, bool admin, bool reboot, string risk)
    {
        var configured = string.Equals(current, target, StringComparison.OrdinalIgnoreCase);
        items.Add(new OptimizationRecommendation
        {
            Id = id, Category = category,
            Title = configured ? $"{title} — currently configured" : $"{title} — change recommended",
            CurrentState = string.IsNullOrWhiteSpace(current) ? "Not set" : current, TargetState = target,
            Why = configured ? $"This setting is already at GPTOPT's baseline. {why}" : why,
            How = how, ExpectedImpact = configured ? "Baseline already active" : impact, Risk = risk,
            RequiresAdmin = admin, RequiresReboot = reboot, CanApply = true,
            IsSelected = !configured && id is "game-mode" or "game-dvr"
        });
    }
}