using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace GPTOPT.App.Services;

public sealed class NetworkQualityService
{
    public async Task<string> BuildReportAsync(IProgress<string>? status = null)
    {
        status?.Report("Measuring local gateway and internet path quality…");
        var json = await RunPowerShellCaptureAsync(@"
$adapter=Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Up' -and $_.HardwareInterface} | Sort-Object LinkSpeed -Descending | Select-Object -First 1
$config=if($adapter){Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue}else{$null}
$gateway=if($config -and $config.IPv4DefaultGateway){$config.IPv4DefaultGateway.NextHop}else{$null}
function Measure-Target([string]$target,[int]$count=12){
  if(-not $target){return $null}
  $samples=@()
  for($i=0;$i -lt $count;$i++){
    $r=Test-Connection -TargetName $target -Count 1 -TimeoutSeconds 2 -ErrorAction SilentlyContinue
    if($r){$samples += [double]$r.Latency}
  }
  $received=$samples.Count
  $loss=[math]::Round((1-($received/[double]$count))*100,1)
  if($received -eq 0){return [pscustomobject]@{Target=$target;Sent=$count;Received=0;LossPercent=100;AverageMs=$null;MinimumMs=$null;MaximumMs=$null;JitterMs=$null}}
  $avg=($samples|Measure-Object -Average).Average
  $variance=($samples|ForEach-Object{[math]::Pow($_-$avg,2)}|Measure-Object -Average).Average
  [pscustomobject]@{Target=$target;Sent=$count;Received=$received;LossPercent=$loss;AverageMs=[math]::Round($avg,2);MinimumMs=[math]::Round(($samples|Measure-Object -Minimum).Minimum,2);MaximumMs=[math]::Round(($samples|Measure-Object -Maximum).Maximum,2);JitterMs=[math]::Round([math]::Sqrt($variance),2)}
}
$route=@()
try{$route=Test-NetConnection -ComputerName 1.1.1.1 -TraceRoute -Hops 8 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Select-Object -ExpandProperty TraceRoute}catch{}
[pscustomobject]@{
 Adapter=if($adapter){[pscustomobject]@{Name=$adapter.Name;Description=$adapter.InterfaceDescription;LinkSpeed=[string]$adapter.LinkSpeed;MacAddress=$adapter.MacAddress}}else{$null}
 Gateway=$gateway
 DnsServers=if($config){@($config.DNSServer.ServerAddresses)}else{@()}
 GatewayQuality=Measure-Target $gateway 12
 InternetQuality=Measure-Target '1.1.1.1' 12
 AlternateQuality=Measure-Target '8.8.8.8' 8
 Route=@($route)
} | ConvertTo-Json -Depth 6");

        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        var gateway = ReadProbe(root, "GatewayQuality");
        var internet = ReadProbe(root, "InternetQuality");
        var alternate = ReadProbe(root, "AlternateQuality");
        var verdict = Classify(internet, alternate);

        var report = new StringBuilder();
        report.AppendLine("GPTOPT NETWORK QUALITY");
        report.AppendLine($"Generated: {DateTime.Now:F}");
        report.AppendLine();
        report.AppendLine("DECISION");
        report.AppendLine($"Status: {verdict.Status}");
        report.AppendLine(verdict.Summary);
        report.AppendLine();
        report.AppendLine("WHY IT MATTERS");
        report.AppendLine("Latency is the round-trip delay. Jitter is variation between samples. Packet loss is missing traffic. Stable low jitter and zero loss matter more than a single best ping.");
        report.AppendLine("GPTOPT measures the current path; it does not claim that registry edits can create a shorter Internet route.");
        report.AppendLine();
        report.AppendLine("ACTIVE PATH");
        if (root.TryGetProperty("Adapter", out var adapter) && adapter.ValueKind == JsonValueKind.Object)
        {
            report.AppendLine($"Adapter: {Read(adapter, "Name")}");
            report.AppendLine($"Hardware: {Read(adapter, "Description")}");
            report.AppendLine($"Link speed: {Read(adapter, "LinkSpeed")}");
        }
        report.AppendLine($"Gateway: {Read(root, "Gateway")}");
        report.AppendLine($"DNS: {string.Join(", ", ReadArray(root, "DnsServers"))}");
        report.AppendLine();
        AppendProbe(report, "LOCAL GATEWAY", gateway);
        AppendProbe(report, "INTERNET — CLOUDFLARE", internet);
        AppendProbe(report, "INTERNET — GOOGLE", alternate);
        report.AppendLine("ROUTE EVIDENCE");
        var route = ReadArray(root, "Route");
        report.AppendLine(route.Length == 0 ? "No traceroute hops returned." : string.Join("\n", route.Select((hop, index) => $"{index + 1}. {hop}")));
        report.AppendLine();
        report.AppendLine("ACTION");
        report.AppendLine(verdict.Action);
        report.AppendLine("Repeat the measurement during the exact time Halo feels bad. A clean idle test cannot disprove congestion or route instability during gameplay.");
        return report.ToString();
    }

    private static Verdict Classify(Probe? primary, Probe? alternate)
    {
        var probes = new[] { primary, alternate }.Where(x => x is not null).Cast<Probe>().ToArray();
        if (probes.Length == 0 || probes.All(x => x.Received == 0))
            return new("NO RESULT", "No Internet probe returned. Check the adapter, gateway, firewall, or connection state.", "Verify the wired adapter and gateway first. Do not apply network tweaks without a valid baseline.");
        var worstLoss = probes.Max(x => x.LossPercent);
        var worstJitter = probes.Where(x => x.JitterMs.HasValue).Select(x => x.JitterMs!.Value).DefaultIfEmpty(0).Max();
        if (worstLoss >= 5)
            return new("UNSTABLE", $"Packet loss reached {worstLoss:0.#}%. This can cause rubber-banding, delayed actions, and disconnects.", "Test the gateway. If gateway loss is zero but Internet loss remains, compare times/routes and contact the ISP before changing Windows.");
        if (worstLoss > 0 || worstJitter >= 15)
            return new("REVIEW", $"The path has {(worstLoss > 0 ? $"{worstLoss:0.#}% loss" : "no measured loss")} and up to {worstJitter:0.##} ms jitter.", "Repeat while Halo feels wrong. Separate local gateway instability from upstream route instability.");
        return new("STABLE BASELINE", $"No packet loss was measured and jitter stayed at or below {worstJitter:0.##} ms.", "Keep the current network configuration. Only investigate further if in-game symptoms recur at a specific time or server region.");
    }

    private static void AppendProbe(StringBuilder report, string title, Probe? probe)
    {
        report.AppendLine(title);
        if (probe is null) { report.AppendLine("Unavailable."); report.AppendLine(); return; }
        report.AppendLine($"Target: {probe.Target}");
        report.AppendLine($"Received: {probe.Received}/{probe.Sent}");
        report.AppendLine($"Loss: {probe.LossPercent:0.#}%");
        report.AppendLine($"Average: {Format(probe.AverageMs)} ms");
        report.AppendLine($"Minimum / maximum: {Format(probe.MinimumMs)} / {Format(probe.MaximumMs)} ms");
        report.AppendLine($"Jitter (standard deviation): {Format(probe.JitterMs)} ms");
        report.AppendLine();
    }

    private static Probe? ReadProbe(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Object) return null;
        return new Probe(Read(value, "Target"), ReadInt(value, "Sent"), ReadInt(value, "Received"), ReadDouble(value, "LossPercent"), ReadNullableDouble(value, "AverageMs"), ReadNullableDouble(value, "MinimumMs"), ReadNullableDouble(value, "MaximumMs"), ReadNullableDouble(value, "JitterMs"));
    }

    private static string Read(JsonElement element, string name) => element.TryGetProperty(name, out var value) ? value.ToString() : string.Empty;
    private static int ReadInt(JsonElement element, string name) => element.TryGetProperty(name, out var value) && value.TryGetInt32(out var result) ? result : 0;
    private static double ReadDouble(JsonElement element, string name) => element.TryGetProperty(name, out var value) && value.TryGetDouble(out var result) ? result : 0;
    private static double? ReadNullableDouble(JsonElement element, string name) => element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var result) ? result : null;
    private static string[] ReadArray(JsonElement element, string name) => element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array ? value.EnumerateArray().Select(x => x.ToString()).Where(x => !string.IsNullOrWhiteSpace(x)).ToArray() : [];
    private static string Format(double? value) => value.HasValue ? value.Value.ToString("0.##", CultureInfo.InvariantCulture) : "n/a";

    private static async Task<string> RunPowerShellCaptureAsync(string command)
    {
        var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(command));
        var start = new ProcessStartInfo("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -EncodedCommand {encoded}") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start network diagnostics.");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var output = await outputTask;
        var error = await errorTask;
        if (process.ExitCode != 0 || string.IsNullOrWhiteSpace(output)) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? "Network diagnostics returned no data." : error.Trim());
        return output;
    }

    private sealed record Probe(string Target, int Sent, int Received, double LossPercent, double? AverageMs, double? MinimumMs, double? MaximumMs, double? JitterMs);
    private sealed record Verdict(string Status, string Summary, string Action);
}