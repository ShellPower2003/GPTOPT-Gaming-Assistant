namespace GPTOPT.App.Models;

public sealed class AuditReport
{
    public string AuditId { get; set; } = "No audit found";
    public string CollectedUtc { get; set; } = string.Empty;
    public PlatformInfo Platform { get; set; } = new();
    public GamingInfo Gaming { get; set; } = new();
    public DeviceInfo Devices { get; set; } = new();
    public HealthInfo Health { get; set; } = new();
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
}
