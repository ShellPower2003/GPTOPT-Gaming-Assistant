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
  @{Name='Hardware/WHEA'; Log='System'; Providers=@('Microsoft-Windows-WHEA-Logger'); Ids=@()},
  @{Name='Display/GPU'; Log='System'; Providers=@('Display','nvlddmkm'); Ids=@(4101)},
  @{Name='Storage'; Log='System'; Providers=@('disk','stornvme','storahci','Ntfs'); Ids=@(7,11,51,55,129,153)},
  @{Name='USB/Controller'; Log='System'; Providers=@('Microsoft-Windows-Kernel-PnP','Kernel-PnP','USBHUB3','Microsoft-Windows-DriverFrameworks-UserMode'); Ids=@(2003,2100,2102,219)}
)
$results = foreach($g in $groups){
  $items=Get-WinEvent -FilterHashtable @{LogName=$g.Log;StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue |
    Where-Object { ($g.Providers -contains $_.ProviderName) -or ($g.Ids.Count -gt 0 -and $g.Ids -contains $_.Id) }
  [pscustomobject]@{Category=$g.Name;Count=@($items).Count;Latest=(@($items)|Sort-Object TimeCreated -Descending|Select-Object -First 1 -ExpandProperty TimeCreated)}
}
$results | ConvertTo-Csv -NoTypeInformation");
        report.AppendLine("EVENT CLASSIFICATION (LAST 72 HOURS)");
        report.AppendLine(string.IsNullOrWhiteSpace(events) ? "No matching hardware, GPU, storage, or USB events." : events.Trim());
        report.AppendLine();

        status?.Report("Identifying crashing applications...");
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
        report.AppendLine("APPLICATION CRASHES (LAST 72 HOURS)");
        report.AppendLine(string.IsNullOrWhiteSpace(crashes) ? "None found." : crashes.Trim());
        report.AppendLine();

        status?.Report("Checking controller path...");
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
        report.AppendLine("CONTROLLER PATH");
        report.AppendLine(string.IsNullOrWhiteSpace(controller) ? "No controller information returned." : controller.Trim());
        report.AppendLine();

        status?.Report("Checking pending reboot sources...");
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
        report.AppendLine("PENDING REBOOT SOURCES");
        report.AppendLine(string.IsNullOrWhiteSpace(reboot) ? "No reboot-source information returned." : reboot.Trim());
        report.AppendLine();

        report.AppendLine("INTERPRETATION");
        report.AppendLine("• Zero WHEA, display-reset, storage-timeout, and USB/controller events is a strong result.");
        report.AppendLine("• Application crash counts are not treated as gaming faults until the crashing executable is identified above.");
        report.AppendLine("• Controller devices are restricted to actual game-controller matches; host controllers and unrelated system devices are excluded.");
        report.AppendLine("• PendingFileRename lists the affected filenames so a stale entry can be distinguished from a real update or driver reboot.");
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
