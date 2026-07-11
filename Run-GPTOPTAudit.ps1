#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoPublish
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSCommandPath
$Collector = Join-Path $Root 'Scripts\Invoke-GPTOPTAudit.ps1'

if (-not (Test-Path -LiteralPath $Collector)) {
    throw "GPTOPT audit collector not found: $Collector"
}

if ($NoPublish) {
    & $Collector
}
else {
    & $Collector -Publish
}
