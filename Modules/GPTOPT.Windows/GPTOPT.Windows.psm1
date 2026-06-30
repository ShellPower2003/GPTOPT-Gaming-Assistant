function New-Result {
    param([string]$Category,[string]$Severity,[string]$Status,[string]$Finding,[object[]]$Evidence,[string]$Action,[string]$Source,[string]$Confidence='High')
    [pscustomobject][ordered]@{
        Timestamp=[DateTime]::UtcNow.ToString('o'); Module=$MyInvocation.MyCommand.ModuleName; Category=$Category
        Severity=$Severity; Status=$Status; Finding=$Finding; Evidence=@($Evidence); RecommendedAction=$Action
        Risk='None'; UndoAvailable=$false; Source=$Source; Confidence=$Confidence
    }
}
function New-Evidence { param([string]$Name,$Value,[string]$Source)
    [pscustomobject][ordered]@{Name=$Name;Value=$Value;Source=$Source;CollectedAt=[DateTime]::UtcNow.ToString('o')}
}
function Test-GPTOPTModulePrerequisite {
    $ok=[Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    New-Result 'Prerequisite' $(if($ok){'None'}else{'Critical'}) $(if($ok){'PASS'}else{'FAIL'}) $(if($ok){'Windows diagnostic APIs are available.'}else{'This module requires Windows.'}) @(New-Evidence 'Platform' ([Environment]::OSVersion.Platform.ToString()) '.NET Environment.OSVersion') $(if($ok){''}else{'Run GPTOPT on Windows.'}) '.NET Environment.OSVersion'
}
function Invoke-GPTOPTAudit {
    try {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $ok=[int]$os.BuildNumber -ge 19045
        New-Result 'Windows' $(if($ok){'None'}else{'Medium'}) $(if($ok){'PASS'}else{'WARN'}) ("{0}, build {1}" -f $os.Caption,$os.BuildNumber) @(
            New-Evidence 'Caption' $os.Caption 'CIM Win32_OperatingSystem'
            New-Evidence 'BuildNumber' $os.BuildNumber 'CIM Win32_OperatingSystem'
        ) $(if($ok){''}else{'Confirm this Windows release is supported.'}) 'CIM Win32_OperatingSystem'
    } catch { New-Result 'Windows' 'High' 'UNKNOWN' 'Windows version could not be collected.' @(New-Evidence 'Error' $_.Exception.Message 'Get-CimInstance') 'Rerun from Windows PowerShell.' 'CIM Win32_OperatingSystem' 'Low' }
    try {
        $cpu=Get-CimInstance Win32_Processor -ErrorAction Stop|Select-Object -First 1
        New-Result 'Hardware' 'None' 'INFO' ("CPU: {0}" -f $cpu.Name.Trim()) @(
            New-Evidence 'Name' $cpu.Name.Trim() 'CIM Win32_Processor'
            New-Evidence 'LogicalProcessors' $cpu.NumberOfLogicalProcessors 'CIM Win32_Processor'
        ) '' 'CIM Win32_Processor'
    } catch { New-Result 'Hardware' 'Low' 'UNKNOWN' 'CPU information could not be collected.' @(New-Evidence 'Error' $_.Exception.Message 'Get-CimInstance') 'Confirm WMI is available.' 'CIM Win32_Processor' 'Low' }
    try {
        $gpus=@(Get-CimInstance Win32_VideoController -ErrorAction Stop)
        if($gpus.Count -eq 0){throw 'No display adapter returned.'}
        foreach($gpu in $gpus){
            New-Result 'Graphics' 'None' 'INFO' ("GPU: {0}; driver {1}" -f $gpu.Name,$gpu.DriverVersion) @(
                New-Evidence 'Name' $gpu.Name 'CIM Win32_VideoController'
                New-Evidence 'DriverVersion' $gpu.DriverVersion 'CIM Win32_VideoController'
            ) 'Record this driver in capture metadata.' 'CIM Win32_VideoController'
        }
    } catch { New-Result 'Graphics' 'Medium' 'UNKNOWN' 'GPU information could not be collected.' @(New-Evidence 'Error' $_.Exception.Message 'Get-CimInstance') 'Confirm the display driver is installed.' 'CIM Win32_VideoController' 'Low' }
    try {
        $plan=@(& powercfg.exe /getactivescheme 2>&1)-join ' '
        New-Result 'Power' 'None' 'INFO' ("Active power plan: {0}" -f $plan.Trim()) @(New-Evidence 'ActiveScheme' $plan.Trim() 'powercfg /getactivescheme') 'Keep this constant across comparisons.' 'powercfg /getactivescheme'
    } catch { New-Result 'Power' 'Low' 'UNKNOWN' 'Active power plan could not be read.' @(New-Evidence 'Error' $_.Exception.Message 'powercfg') 'Run powercfg /getactivescheme manually.' 'powercfg /getactivescheme' 'Low' }
}
function Invoke-GPTOPTAnalyze { param([object[]]$Evidence) @($Evidence) }
function Invoke-GPTOPTApply { New-Result 'Safety' 'None' 'INFO' 'This module is audit-only; no change was applied.' @() '' 'Module policy' }
function Invoke-GPTOPTUndo { New-Result 'Safety' 'None' 'INFO' 'No module change exists to undo.' @() '' 'Module policy' }
function Export-GPTOPTReport { param([object[]]$Results) @($Results) }
Export-ModuleMember -Function Test-GPTOPTModulePrerequisite,Invoke-GPTOPTAudit,Invoke-GPTOPTAnalyze,Invoke-GPTOPTApply,Invoke-GPTOPTUndo,Export-GPTOPTReport
