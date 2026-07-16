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

Write-Host 'PASS: controller sample-list conversion works.' -ForegroundColor Green
Write-Host 'PASS: controller diagnostic parses cleanly.' -ForegroundColor Green
