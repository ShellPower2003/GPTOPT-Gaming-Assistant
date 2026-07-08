[CmdletBinding()]
param([string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPTOPT-Logs'),[switch]$NoOpen)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host ''; Write-Host 'GPTOPT Gaming Assistant' -ForegroundColor Cyan
Write-Host 'Read-only evidence audit. No system or game settings will be changed.' -ForegroundColor Green
$results=@(& (Join-Path $root 'Scripts\Invoke-GPTOPTAudit.ps1') -OutputPath $OutputPath)
$review=@($results|Where-Object{$_.Status -in @('ACTION','FAIL','WARN')}).Count
$html=Get-ChildItem $OutputPath -File -Filter 'GPTOPT-Audit-*.html'|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
Write-Host ("Audit complete: {0} results; {1} items to review." -f $results.Count,$review) -ForegroundColor Cyan
Write-Host ("Reports: {0}" -f $OutputPath)
if(-not $NoOpen -and $html){Start-Process $html.FullName}
$results
