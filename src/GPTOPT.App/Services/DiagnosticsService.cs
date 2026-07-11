using System.Diagnostics;
using System.Text;

namespace GPTOPT.App.Services;

public sealed class DiagnosticsService
{
    public async Task<string> BuildReportAsync(IProgress<string>? status = null)
    {
        var report = new StringBuilder();
        report.AppendLine("GPTOPT TARGETED DIAGNOSTICS");
        report.AppendLine($"Generated: {DateTime.Now:F}");
        report.AppendLine();

        status?.Report("Checking problem devices...");
        var devices = await RunPowerShellCaptureAsync(@"
Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
Select-Object Name,PNPClass,ConfigManagerErrorCode,Status |
ConvertTo-Csv -NoTypeInformation");
        report.AppendLine("PROBLEM DEVICES");
        report.AppendLine(string.IsNullOrWhiteSpace(devices) ? "None reported." : devices.Trim());
        report.AppendLine();

        status?.Report("Classifying recent system events...");
        var events = await RunPowerShellCaptureAsync(@"
$start=(Get-Date).AddDays(-3)
$groups = @(
  @{Name='Hardware/WHEA'; Log='System'; Providers='Microsoft-Windows-WHEA-Logger'; Ids=@()},
  @{Name='Display/GPU'; Log='System'; Providers='Display','nvlddmkm'; Ids=@(4101)},
  @{Name='Storage'; Log='System'; Providers='disk','stornvme','storahci','Ntfs'; Ids=@(7,11,51,55,129,153)},
  @{Name='USB/Controller'; Log='System'; Providers='Kernel-PnP','USBHUB3','Microsoft-Windows-DriverFrameworks-UserMode'; Ids=@(2003,2100,2102,219)},
  @{Name='Application Crashes'; Log='Application'; Providers='Application Error','Windows Error Reporting'; Ids=@(1000,1001)}
)
foreach($g in $groups){
  $items=Get-WinEvent -FilterHashtable @{LogName=$g.Log;StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue |
    Where-Object { ($g.Providers -contains $_.ProviderName) -or ($g.Ids.Count -gt 0 -and $g.Ids -contains $_.Id) }
  [pscustomobject]@{Category=$g.Name;Count=@($items).Count;Latest=(@($items)|Sort-Object TimeCreated -Descending|Select-Object -First 1 -ExpandProperty TimeCreated)}
} | ConvertTo-Csv -NoTypeInformation");
        report.AppendLine("EVENT CLASSIFICATION (LAST 72 HOURS)");
        report.AppendLine(string.IsNullOrWhiteSpace(events) ? "No matching critical categories found." : events.Trim());
        report.AppendLine();

        status?.Report("Checking controller path...");
        var controller = await RunPowerShellCaptureAsync(@"
$devices=Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'Flydigi|Vader|Xbox|Controller|Gamepad' }
$svc=Get-Service GameControllerService -ErrorAction SilentlyContinue
[pscustomobject]@{Detected=@($devices).Count;DeviceNames=($devices.FriendlyName -join '; ');ServiceStatus=$svc.Status;ServiceStartType=$svc.StartType} | ConvertTo-Json -Compress");
        report.AppendLine("CONTROLLER PATH");
        report.AppendLine(string.IsNullOrWhiteSpace(controller) ? "No controller information returned." : controller.Trim());
        report.AppendLine();

        status?.Report("Checking pending reboot sources...");
        var reboot = await RunPowerShellCaptureAsync(@"
[pscustomobject]@{
 WindowsUpdate=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
 CBS=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
 PendingFileRename=$null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
} | ConvertTo-Json -Compress");
        report.AppendLine("PENDING REBOOT SOURCES");
        report.AppendLine(reboot.Trim());
        report.AppendLine();

        report.AppendLine("INTERPRETATION");
        report.AppendLine("• WHEA events matter most because they can indicate hardware instability.");
        report.AppendLine("• Display 4101 or nvlddmkm events can indicate driver resets or GPU instability.");
        report.AppendLine("• Storage 129/153 events can correlate with severe hitching.");
        report.AppendLine("• Kernel-PnP/USB events can explain controller or audio disconnects.");
        report.AppendLine("• Application Error/Windows Error Reporting counts should be tied to the actual crashing process before action.");
        return report.ToString();
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
        var output = await process.StandardOutput.ReadToEndAsync();
        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0 && string.IsNullOrWhiteSpace(output)) throw new InvalidOperationException(error);
        return output;
    }
}
