#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(0,3)][int]$ControllerIndex = 0,
    [switch]$Publish,
    [switch]$NoPause,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$diagnostic = Join-Path $root 'Scripts\Invoke-GPTOPTControllerAimCheck.ps1'
if (-not (Test-Path -LiteralPath $diagnostic)) { throw "Controller aim diagnostic not found: $diagnostic" }
$arguments = @{}
if ($PSBoundParameters.ContainsKey('ControllerIndex')) { $arguments.ControllerIndex = $ControllerIndex }
if ($Publish) { $arguments.Publish = $true }
if ($NoPause) { $arguments.NoPause = $true }
if ($SelfTest) { $arguments.SelfTest = $true }
& $diagnostic @arguments
