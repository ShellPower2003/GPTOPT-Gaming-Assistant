namespace GPTOPT.App.Models;

public sealed class AuditReport
{
    public string AuditId { get; set; } = "No audit found";
    public string CollectedUtc { get; set; } = string.Empty;
    public PlatformInfo Platform { get; set; } = new();
    public GamingInfo Gaming { get; set; } = new();
    public DeviceInfo Devices { get; set; } = new();
    public HealthInfo Health { get; set; } = new();
    public ReadinessInfo Readiness { get; set; } = new();
}

public sealed class PlatformInfo
{
    public string Windows { get; set; } = string.Empty;
    public string Build { get; set; } = string.Empty;
    public string Bios { get; set; } = string.Empty;
    public string Cpu { get; set; } = string.Empty;
    public string Gpu { get; set; } = string.Empty;
    public double MemoryGb { get; set; }
    public string Display { get; set; } = string.Empty;
}

public sealed class GamingInfo
{
    public string PowerPlan { get; set; } = string.Empty;
    public string GameMode { get; set; } = string.Empty;
    public string GameDvr { get; set; } = string.Empty;
    public string Hags { get; set; } = string.Empty;
    public string MpoOverride { get; set; } = string.Empty;
}

public sealed class DeviceInfo
{
    public bool FlydigiDetected { get; set; }
    public string NvidiaDriver { get; set; } = string.Empty;
    public int ActiveWiredAdapters { get; set; }
    public int ActiveWifiAdapters { get; set; }
    public string[] GptoptProcesses { get; set; } = [];
}

public sealed class HealthInfo
{
    public int SystemErrorCount { get; set; }
    public int ApplicationErrorCount { get; set; }
    public int ProblemDeviceCount { get; set; }
    public int PendingRebootCount { get; set; }
    public double SystemDriveFreeGb { get; set; }
    public int WheaCount { get; set; }
    public int DisplayResetCount { get; set; }
    public int StorageFaultCount { get; set; }
    public int ControllerFaultCount { get; set; }
    public int GamingCrashCount { get; set; }
    public int BackgroundCrashCount { get; set; }
    public string[] ProblemDeviceNames { get; set; } = [];
    public string[] PendingRebootSources { get; set; } = [];
    public string[] PendingRenameFiles { get; set; } = [];
    public string[] GamingCrashApps { get; set; } = [];
    public string[] BackgroundCrashApps { get; set; } = [];
}

public sealed class ReadinessInfo
{
    public int Score { get; set; } = 100;
    public string Status { get; set; } = "Unknown";
    public string Summary { get; set; } = "Run a scan to calculate gaming readiness.";
    public string[] Blockers { get; set; } = [];
    public string[] Warnings { get; set; } = [];
    public string[] PassedChecks { get; set; } = [];
}
