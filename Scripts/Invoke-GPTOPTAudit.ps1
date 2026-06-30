[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPTOPT-Logs'),
    [string]$ModulesPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-RunnerResult {
    param(
        [string]$Module,
        [string]$Status,
        [string]$Severity,
        [string]$Finding,
        [string]$RecommendedAction,
        [string]$Source,
        [string]$Confidence = 'High'
    )

    [pscustomobject][ordered]@{
        Timestamp = [DateTime]::UtcNow.ToString('o')
        Module = $Module
        Category = 'AuditEngine'
        Severity = $Severity
        Status = $Status
        Finding = $Finding
        Evidence = @([pscustomobject]@{
            Name = 'ModulesPath'
            Value = $ModulesPath
            Source = $Source
            CollectedAt = [DateTime]::UtcNow.ToString('o')
        })
        RecommendedAction = $RecommendedAction
        Risk = 'None'
        UndoAvailable = $false
        Source = $Source
        Confidence = $Confidence
    }
}

function Test-ResultShape {
    param([Parameter(Mandatory)]$Result)

    $required = @(
        'Timestamp', 'Module', 'Category', 'Severity', 'Status', 'Finding',
        'Evidence', 'RecommendedAction', 'Risk', 'UndoAvailable', 'Source', 'Confidence'
    )

    foreach ($name in $required) {
        if ($null -eq $Result.PSObject.Properties[$name]) { return $false }
    }

    return ($Result.Status -in @('PASS', 'WARN', 'FAIL', 'ACTION', 'INFO', 'UNKNOWN')) -and
        ($Result.Severity -in @('None', 'Low', 'Medium', 'High', 'Critical')) -and
        ($Result.Confidence -in @('Low', 'Medium', 'High'))
}

$results = [System.Collections.Generic.List[object]]::new()
$manifests = @()
if (Test-Path -LiteralPath $ModulesPath) {
    $manifests = @(Get-ChildItem -LiteralPath $ModulesPath -Recurse -File -Filter '*.psd1')
}

if ($manifests.Count -eq 0) {
    $results.Add((New-RunnerResult -Module 'GPTOPT.Core' -Status 'INFO' -Severity 'None' -Finding 'No diagnostic modules were discovered.' -RecommendedAction 'Install or create a module that implements the GPTOPT module contract.' -Source 'Scripts/Invoke-GPTOPTAudit.ps1'))
}

foreach ($manifest in $manifests) {
    $module = $null
    try {
        $module = Import-Module -Name $manifest.FullName -Force -PassThru
        $auditCommand = Get-Command -Name "$($module.Name)\Invoke-GPTOPTAudit" -ErrorAction Stop
        $prerequisiteCommand = Get-Command -Name "$($module.Name)\Test-GPTOPTModulePrerequisite" -ErrorAction Stop

        $prerequisites = @(& $prerequisiteCommand)
        foreach ($item in $prerequisites) {
            if (Test-ResultShape -Result $item) { $results.Add($item) }
            else { throw "Module '$($module.Name)' returned an invalid prerequisite result." }
        }

        $auditResults = @(& $auditCommand)
        foreach ($item in $auditResults) {
            if (Test-ResultShape -Result $item) { $results.Add($item) }
            else { throw "Module '$($module.Name)' returned an invalid audit result." }
        }
    }
    catch {
        $results.Add((New-RunnerResult -Module $manifest.BaseName -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -RecommendedAction 'Review the module manifest, exported commands, and result contract.' -Source $manifest.FullName -Confidence 'High'))
    }
    finally {
        if ($null -ne $module) { Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue }
        $module = $null
    }
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$base = Join-Path $OutputPath "GPTOPT-Audit-$stamp"

ConvertTo-Json -InputObject @($results) -Depth 10 | Set-Content -LiteralPath "$base.json" -Encoding UTF8
@($results) | Export-Csv -LiteralPath "$base.csv" -NoTypeInformation -Encoding UTF8
@($results) | Format-Table Status, Severity, Module, Finding -AutoSize | Out-String |
    Set-Content -LiteralPath "$base.txt" -Encoding UTF8
@($results) | Select-Object Timestamp, Status, Severity, Module, Category, Finding, RecommendedAction |
    ConvertTo-Html -Title 'GPTOPT Gaming Assistant Audit' -PreContent '<h1>GPTOPT Gaming Assistant Audit</h1><p>Audit-only report. No system changes were made.</p>' |
    Set-Content -LiteralPath "$base.html" -Encoding UTF8

foreach ($result in $results) {
    $color = switch ($result.Status) {
        'PASS' { 'Green' }
        'WARN' { 'Yellow' }
        'ACTION' { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host ("[{0}] {1}: {2}" -f $result.Status, $result.Module, $result.Finding) -ForegroundColor $color
}

Write-Host "Reports: $base.{json,csv,txt,html}"
@($results)
