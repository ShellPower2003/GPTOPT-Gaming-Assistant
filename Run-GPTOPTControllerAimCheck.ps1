#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(0,3)][int]$ControllerIndex = 0
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$diagnostic = Join-Path $root 'Scripts\Invoke-GPTOPTControllerAimCheck.ps1'
if (-not (Test-Path -LiteralPath $diagnostic)) { throw "Controller aim diagnostic not found: $diagnostic" }
if ($PSBoundParameters.ContainsKey('ControllerIndex')) { & $diagnostic -ControllerIndex $ControllerIndex }
else { & $diagnostic }
