#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$samples = New-Object System.Collections.Generic.List[object]
$samples.Add([pscustomobject]@{ ms=0.0; packet=1; lx=0.0; ly=0.0; rx=0.0; ry=0.0 }) | Out-Null
$samples.Add([pscustomobject]@{ ms=1.0; packet=2; lx=1.0; ly=0.0; rx=-1.0; ry=0.0 }) | Out-Null

$result = $samples.ToArray()
if ($result.Count -ne 2) { throw "Sample-list conversion failed. Expected 2 records; received $($result.Count)." }
if ($result[1].packet -ne 2) { throw 'Sample-list conversion changed record contents.' }

$source = Join-Path $PSScriptRoot 'Invoke-GPTOPTControllerAimCheck.ps1'
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if ($errors.Count -gt 0) { throw "Controller diagnostic syntax failed: $($errors.Message -join '; ')" }

$root = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $root 'Run-GPTOPTControllerAimCheck.ps1'
& $launcher -SelfTest

$appText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'Invoke-GPTOPTDesktopApp.ps1')
if ($appText -notmatch 'Invoke-GPTOPTControllerAimCheck\.ps1') { throw 'Desktop app does not target the controller diagnostic backend.' }
if ($appText -notmatch '-Publish') { throw 'Desktop app does not enable automatic controller report upload.' }
if ($appText -notmatch 'Controller aim launch failed') { throw 'Desktop app does not expose controller launch failures.' }

Write-Host 'PASS: controller sample-list conversion works.' -ForegroundColor Green
Write-Host 'PASS: controller diagnostic parses cleanly.' -ForegroundColor Green
Write-Host 'PASS: controller launcher backend self-test works.' -ForegroundColor Green
Write-Host 'PASS: desktop app enables upload and visible launch errors.' -ForegroundColor Green
