param([string]$RepoRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference='Stop'
$temp=Join-Path ([IO.Path]::GetTempPath()) ("GPTOPT-Test-{0}" -f [Guid]::NewGuid())
try{
 $results=@(& (Join-Path $RepoRoot 'Scripts\Invoke-GPTOPTAudit.ps1') -OutputPath $temp -ModulesPath (Join-Path $RepoRoot 'Modules'))
 if($results.Count -lt 8){throw "Expected at least 8 results; got $($results.Count)."}
 $required=@('Timestamp','Module','Category','Severity','Status','Finding','Evidence','RecommendedAction','Risk','UndoAvailable','Source','Confidence')
 foreach($result in $results){foreach($property in $required){if($null -eq $result.PSObject.Properties[$property]){throw "$($result.Module) missing $property."}}}
 foreach($ext in 'json','csv','txt','html'){$file=Get-ChildItem $temp -File -Filter "*.$ext"|Select-Object -First 1;if(-not $file -or $file.Length -eq 0){throw "Missing $ext report."}}
 $jsonFile=Get-ChildItem $temp -File -Filter '*.json'|Select-Object -First 1
 $saved=Get-Content -Raw $jsonFile.FullName|ConvertFrom-Json
 if($saved.Count -ne $results.Count){throw 'JSON count mismatch.'}
 Write-Host ("GPTOPT smoke test passed: {0} results." -f $results.Count) -ForegroundColor Green
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
