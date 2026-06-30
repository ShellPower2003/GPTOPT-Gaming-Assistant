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
    New-Result 'Prerequisite' 'None' 'PASS' 'Process inventory is available.' @(New-Evidence 'Command' 'Get-Process' 'PowerShell') '' 'PowerShell Get-Process'
}
function Invoke-GPTOPTAudit {
    $overlayNames=@('Discord','GameBar','GameBarFTServer','RTSS','MSIAfterburner','NVIDIAOverlay','nvsphelper64','obs64','Overwolf')
    $captureNames=@('CapFrameX','PresentMon','RTSS')
    $processes=@(Get-Process -ErrorAction SilentlyContinue)
    $overlays=@($processes|Where-Object{$overlayNames -contains $_.ProcessName})
    $unique=@($overlays|Select-Object -ExpandProperty ProcessName -Unique|Sort-Object)
    $evidence=@($overlays|ForEach-Object{New-Evidence 'Process' ("{0} (PID {1})" -f $_.ProcessName,$_.Id) 'PowerShell Get-Process'})
    if($unique.Count -gt 1){
        New-Result 'Overlays' 'Medium' 'ACTION' ("Multiple overlay/capture processes are active: {0}." -f ($unique -join ', ')) $evidence 'Close nonessential overlays one at a time and compare identical captures.' 'PowerShell Get-Process' 'Medium'
    } elseif($unique.Count -eq 1){
        New-Result 'Overlays' 'Low' 'INFO' ("One overlay/capture process is active: {0}." -f $unique[0]) $evidence 'Keep its state constant across comparisons.' 'PowerShell Get-Process' 'Medium'
    } else {
        New-Result 'Overlays' 'None' 'PASS' 'No known overlay conflict was detected in this process snapshot.' @() 'This point-in-time check does not prove an overlay cannot load later.' 'PowerShell Get-Process' 'Medium'
    }
    foreach($name in $captureNames){
        $running=$processes.ProcessName -contains $name
        $command=Get-Command "$name.exe" -ErrorAction SilentlyContinue|Select-Object -First 1
        $available=$running -or $null -ne $command
        New-Result 'CaptureTools' $(if($available){'None'}else{'Low'}) $(if($available){'PASS'}else{'INFO'}) $(if($available){"$name is available."}else{"$name was not running and was not found on PATH."}) @(
            New-Evidence 'Running' $running 'PowerShell Get-Process'
            New-Evidence 'CommandPath' $(if($command){$command.Source}else{'Not found on PATH'}) 'PowerShell Get-Command'
        ) $(if($available){'Record its version in capture metadata.'}else{'Install only if this capture workflow is needed.'}) 'PowerShell process and command inventory' 'Medium'
    }
}
function Invoke-GPTOPTAnalyze { param([object[]]$Evidence) @($Evidence) }
function Invoke-GPTOPTApply { New-Result 'Safety' 'None' 'INFO' 'This module is audit-only; no change was applied.' @() '' 'Module policy' }
function Invoke-GPTOPTUndo { New-Result 'Safety' 'None' 'INFO' 'No module change exists to undo.' @() '' 'Module policy' }
function Export-GPTOPTReport { param([object[]]$Results) @($Results) }
Export-ModuleMember -Function Test-GPTOPTModulePrerequisite,Invoke-GPTOPTAudit,Invoke-GPTOPTAnalyze,Invoke-GPTOPTApply,Invoke-GPTOPTUndo,Export-GPTOPTReport
