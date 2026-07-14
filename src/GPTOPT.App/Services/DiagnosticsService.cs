using System.Diagnostics;
using System.Globalization;
using System.Text;

namespace GPTOPT.App.Services;

public sealed class DiagnosticsService
{
    public async Task<string> BuildReportAsync(IProgress<string>? status = null)
    {
        status?.Report("Checking active problem devices…");
        var devices = await RunPowerShellCaptureAsync(@"
Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
Select-Object Name,PNPClass,ConfigManagerErrorCode,Status |
ConvertTo-Csv -NoTypeInformation");

        status?.Report("Classifying gaming-critical events…");
        var events = await RunPowerShellCaptureAsync(@"
$start=(Get-Date).AddDays(-3)
$all=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue
$controller=@($all | Where-Object {
  ($_.ProviderName -in @('Microsoft-Windows-Kernel-PnP','Kernel-PnP','USBHUB3','Microsoft-Windows-DriverFrameworks-UserMode')) -and
  ($_.Id -in @(2003,2100,2102,219)) -and
  ($_.Message -match '(?i)VID_045E&PID_028E|FLYDIGI_VADER4|GeniTech Virtual Gamepad|Xbox 360 Controller|HID-compliant game controller|gamepad|controller')
})
$groups = @(
  @{Name='Hardware/WHEA'; Items=@($all | Where-Object ProviderName -eq 'Microsoft-Windows-WHEA-Logger')},
  @{Name='Display/GPU'; Items=@($all | Where-Object { $_.ProviderName -in @('Display','nvlddmkm') -or $_.Id -eq 4101 })},
  @{Name='Storage'; Items=@($all | Where-Object { ($_.ProviderName -in @('disk','stornvme','storahci','Ntfs')) -and ($_.Id -in @(7,11,51,55,129,153)) })},
  @{Name='USB/Controller'; Items=$controller}
)
$groups | ForEach-Object {
  [pscustomobject]@{Category=$_.Name;Count=@($_.Items).Count;Latest=(@($_.Items)|Sort-Object TimeCreated -Descending|Select-Object -First 1 -ExpandProperty TimeCreated)}
} | ConvertTo-Csv -NoTypeInformation");

        status?.Report("Collecting controller event evidence…");
        var controllerEvidence = await RunPowerShellCaptureAsync(@"
$start=(Get-Date).AddDays(-3)
Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue |
Where-Object {
  ($_.ProviderName -in @('Microsoft-Windows-Kernel-PnP','Kernel-PnP','USBHUB3','Microsoft-Windows-DriverFrameworks-UserMode')) -and
  ($_.Id -in @(2003,2100,2102,219)) -and
  ($_.Message -match '(?i)VID_045E&PID_028E|FLYDIGI_VADER4|GeniTech Virtual Gamepad|Xbox 360 Controller|HID-compliant game controller|gamepad|controller')
} | Sort-Object TimeCreated -Descending | Select-Object -First 12 @{n='Time';e={$_.TimeCreated}},Id,ProviderName,@{n='Device';e={
  if($_.Message -match '(?i)(VID_045E&PID_028E[^\s,;]*)'){$matches[1]}
  elseif($_.Message -match '(?i)(FLYDIGI_VADER4|GeniTech Virtual Gamepad Device|Xbox 360 Controller for Windows|HID-compliant game controller)'){$matches[1]}
  else{'Controller-related event'}
}} | ConvertTo-Csv -NoTypeInformation");

        status?.Report("Identifying crashing applications…");
        var crashes = await RunPowerShellCaptureAsync(@"
$start=(Get-Date).AddDays(-3)
$items=Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$start;Id=1000,1001} -ErrorAction SilentlyContinue
$rows=foreach($e in $items){
  $name=$null
  if($e.ProviderName -eq 'Application Error' -and $e.Properties.Count -gt 0){$name=[string]$e.Properties[0].Value}
  if(-not $name -and $e.Message -match '(?im)Faulting application name:\s*([^,\r\n]+)'){$name=$matches[1].Trim()}
  if(-not $name -and $e.Message -match '(?im)AppName=([^\r\n]+)'){$name=$matches[1].Trim()}
  if(-not $name){$name=$e.ProviderName}
  [pscustomobject]@{Application=$name;Time=$e.TimeCreated;EventId=$e.Id}
}
$rows | Group-Object Application | ForEach-Object {
  $latest=$_.Group | Sort-Object Time -Descending | Select-Object -First 1
  [pscustomobject]@{Application=$_.Name;Count=$_.Count;Latest=$latest.Time;EventId=$latest.EventId}
} | Sort-Object -Property @{Expression='Count';Descending=$true},@{Expression='Latest';Descending=$true} | ConvertTo-Csv -NoTypeInformation");

        status?.Report("Checking the Flydigi controller path…");
        var controller = await RunPowerShellCaptureAsync(@"
$devices=Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
  $_.FriendlyName -match 'Flydigi|Vader|Xbox 360 Controller|HID-compliant game controller|GeniTech Virtual Gamepad'
} | Select-Object FriendlyName,Class,Status,InstanceId
$svc=Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match 'GameController|Flydigi' -or $_.DisplayName -match 'GameController|Flydigi'
} | Select-Object -First 1 Name,DisplayName,State,StartMode
[pscustomobject]@{
  Detected=@($devices).Count
  Devices=@($devices | ForEach-Object { [pscustomobject]@{Name=$_.FriendlyName;Class=$_.Class;Status=$_.Status} })
  Service=if($svc){[pscustomobject]@{Name=$svc.Name;DisplayName=$svc.DisplayName;State=$svc.State;StartMode=$svc.StartMode}}else{$null}
} | ConvertTo-Json -Depth 5");

        status?.Report("Checking pending reboot sources…");
        var reboot = await RunPowerShellCaptureAsync(@"
$rename=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
$names=@($rename | Where-Object { $_ } | ForEach-Object { Split-Path $_ -Leaf } | Where-Object { $_ } | Select-Object -Unique -First 12)
[pscustomobject]@{
 WindowsUpdate=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
 CBS=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
 PendingFileRename=@($rename).Count -gt 0
 PendingRenameEntryCount=@($rename).Count
 PendingRenameFiles=$names
} | ConvertTo-Json -Depth 4");

        var wheaCount = ExtractCsvCount(events, "Hardware/WHEA");
        var gpuCount = ExtractCsvCount(events, "Display/GPU");
        var storageCount = ExtractCsvCount(events, "Storage");
        var controllerCount = ExtractCsvCount(events, "USB/Controller");
        var problemDeviceCount = CountCsvRows(devices);
        var gamingCrashCount = CountGamingCrashes(crashes);
        var staleGamingServicesRename = reboot.Contains("gamingservicesproxy_11.dll.0", StringComparison.OrdinalIgnoreCase);
        var realRebootSource = reboot.Contains("\"WindowsUpdate\":  true", StringComparison.OrdinalIgnoreCase) ||
                               reboot.Contains("\"CBS\":  true", StringComparison.OrdinalIgnoreCase);

        var blockers = new List<string>();
        var warnings = new List<string>();
        var information = new List<string>();
        if (wheaCount > 0) blockers.Add($"{wheaCount} WHEA hardware event(s) occurred in the last 72 hours.");
        if (gpuCount > 0) blockers.Add($"{gpuCount} GPU/display reset event(s) occurred in the last 72 hours.");
        if (storageCount > 0) blockers.Add($"{storageCount} storage fault or timeout event(s) occurred in the last 72 hours.");
        if (problemDeviceCount > 0) blockers.Add($"{problemDeviceCount} active Plug-and-Play problem device(s) are present.");
        if (controllerCount > 0) warnings.Add($"{controllerCount} confirmed controller-path event(s) require timestamp and device review.");
        if (gamingCrashCount > 0) warnings.Add($"{gamingCrashCount} gaming-related application crash group(s) were identified.");
        if (realRebootSource) warnings.Add("Windows Update or Component Servicing requires a reboot.");
        else if (staleGamingServicesRename) information.Add("A stale Gaming Services rename entry remains. It is cleanup debt, not evidence of current Halo instability.");
        information.Add("Background crashes remain visible below but do not reduce readiness unless the executable is gaming-related.");

        var statusText = blockers.Count > 0 ? "NOT READY" : warnings.Count > 0 ? "READY WITH REVIEW ITEMS" : "READY";
        var score = Math.Clamp(100 - blockers.Count * 18 - warnings.Count * 4 - (staleGamingServicesRename ? 1 : 0), 0, 100);

        var report = new StringBuilder();
        report.AppendLine("GPTOPT TARGETED DIAGNOSTICS");
        report.AppendLine($"Generated: {DateTime.Now:F}");
        report.AppendLine();
        report.AppendLine("DECISION");
        report.AppendLine($"Status: {statusText}");
        report.AppendLine($"Readiness score: {score}/100");
        report.AppendLine(blockers.Count == 0 ? "Gaming-critical hardware checks did not identify a blocker." : "Resolve the blocking evidence before judging Halo performance.");
        report.AppendLine();
        AppendFindingGroup(report, "BLOCKING", blockers, "Why it matters: these findings can invalidate performance testing or indicate instability.");
        AppendFindingGroup(report, "REVIEW", warnings, "Action: open the evidence section, correlate timestamps with gameplay, and only change settings when the event is reproducible.");
        AppendFindingGroup(report, "INFORMATIONAL", information, "Gaming impact: none confirmed from this evidence alone.");

        report.AppendLine("EVIDENCE — PROBLEM DEVICES");
        report.AppendLine(string.IsNullOrWhiteSpace(devices) ? "None reported." : devices.Trim());
        report.AppendLine();
        report.AppendLine("EVIDENCE — EVENT CLASSIFICATION (LAST 72 HOURS)");
        report.AppendLine(string.IsNullOrWhiteSpace(events) ? "No matching gaming-critical events." : events.Trim());
        report.AppendLine();
        report.AppendLine("EVIDENCE — CONTROLLER EVENTS");
        report.AppendLine(string.IsNullOrWhiteSpace(controllerEvidence) ? "No confirmed Vader/Xbox/HID controller-path events matched." : controllerEvidence.Trim());
        report.AppendLine();
        report.AppendLine("EVIDENCE — APPLICATION CRASHES");
        report.AppendLine(string.IsNullOrWhiteSpace(crashes) ? "None found." : crashes.Trim());
        report.AppendLine();
        report.AppendLine("EVIDENCE — CONTROLLER PATH");
        report.AppendLine(string.IsNullOrWhiteSpace(controller) ? "No controller information returned." : controller.Trim());
        report.AppendLine();
        report.AppendLine("EVIDENCE — PENDING REBOOT SOURCES");
        report.AppendLine(string.IsNullOrWhiteSpace(reboot) ? "No reboot-source information returned." : reboot.Trim());
        report.AppendLine();
        report.AppendLine("HOW TO USE THIS REPORT");
        report.AppendLine("• Blocking findings affect readiness immediately.");
        report.AppendLine("• Review findings require timestamp/device correlation; counts alone are not proof of an active fault.");
        report.AppendLine("• Informational findings remain visible but do not justify a tweak or lower the gaming verdict materially.");
        report.AppendLine("• Repeat the same Halo scene and capture conditions before keeping or rolling back any performance change.");
        return report.ToString();
    }

    private static void AppendFindingGroup(StringBuilder report, string title, IReadOnlyCollection<string> findings, string guidance)
    {
        report.AppendLine($"{title} FINDINGS");
        if (findings.Count == 0) report.AppendLine("None.");
        else foreach (var finding in findings) report.AppendLine($"• {finding}");
        report.AppendLine(guidance);
        report.AppendLine();
    }

    private static int CountCsvRows(string csv) => csv.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).Skip(1).Count();

    private static int CountGamingCrashes(string csv)
    {
        var pattern = new[] { "HaloInfinite", "CapFrameX", "PresentMon", "RTSS", "MSIAfterburner", "GameControllerService", "SteelSeries", "NVIDIA", "nvcontainer", "Flydigi", "SpaceStation" };
        return csv.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).Skip(1)
            .Count(line => pattern.Any(name => line.Contains(name, StringComparison.OrdinalIgnoreCase)));
    }

    private static int ExtractCsvCount(string csv, string category)
    {
        foreach (var line in csv.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).Skip(1))
        {
            var fields = ParseCsvLine(line);
            if (fields.Count >= 2 && string.Equals(fields[0], category, StringComparison.OrdinalIgnoreCase) &&
                int.TryParse(fields[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var count)) return count;
        }
        return 0;
    }

    private static List<string> ParseCsvLine(string line)
    {
        var fields = new List<string>();
        var current = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < line.Length; i++)
        {
            var c = line[i];
            if (c == '"')
            {
                if (quoted && i + 1 < line.Length && line[i + 1] == '"') { current.Append('"'); i++; }
                else quoted = !quoted;
            }
            else if (c == ',' && !quoted) { fields.Add(current.ToString()); current.Clear(); }
            else current.Append(c);
        }
        fields.Add(current.ToString());
        return fields;
    }

    private static async Task<string> RunPowerShellCaptureAsync(string command)
    {
        var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(command));
        var start = new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -EncodedCommand {encoded}")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start PowerShell diagnostics.");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var output = await outputTask;
        var error = await errorTask;
        if (process.ExitCode != 0 && string.IsNullOrWhiteSpace(output)) throw new InvalidOperationException(error);
        return output;
    }
}
