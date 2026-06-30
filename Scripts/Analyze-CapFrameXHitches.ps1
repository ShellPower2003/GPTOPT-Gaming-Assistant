# Analyze-CapFrameXHitches.ps1
# Audit-only. Reads CapFrameX/PresentMon CSV or ZIP, detects hitches, writes Desktop\GPTOPT-Logs.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [double]$HitchMs = 8.0
)
$ErrorActionPreference = 'Stop'
$LogDir = Join-Path $env:USERPROFILE 'Desktop\GPTOPT-Logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Report = Join-Path $LogDir "CapFrameX-Hitch-Analysis-$Stamp.txt"
$Summary = Join-Path $LogDir "CapFrameX-Hitch-Analysis-$Stamp.csv"
$TempDir = $null
function Log([string]$Level,[string]$Msg){$l="$Level`: $Msg";Write-Host $l;Add-Content $Report $l}
function Num($v){$d=0.0;if($null -eq $v){return $null};$s=([string]$v).Trim();if([double]::TryParse($s,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$d)){return $d};return $null}
function Col($row,[string[]]$names){$p=@($row.PSObject.Properties.Name);foreach($n in $names){$m=$p|?{$_ -ieq $n}|select -First 1;if($m){return $m}};foreach($n in $names){$m=$p|?{$_ -like "*$n*"}|select -First 1;if($m){return $m}};return $null}
function Corr([double[]]$x,[double[]]$y){if($x.Count -ne $y.Count -or $x.Count -lt 3){return $null};$ax=($x|measure -Average).Average;$ay=($y|measure -Average).Average;$xy=0.0;$x2=0.0;$y2=0.0;for($i=0;$i-lt$x.Count;$i++){$dx=$x[$i]-$ax;$dy=$y[$i]-$ay;$xy+=$dx*$dy;$x2+=$dx*$dx;$y2+=$dy*$dy};if($x2-eq0-or$y2-eq0){return $null};return $xy/[math]::Sqrt($x2*$y2)}
function Pctl([double[]]$v,[double]$p){$s=@($v|sort);if(!$s){return $null};$r=($p/100)*($s.Count-1);$lo=[math]::Floor($r);$hi=[math]::Ceiling($r);if($lo-eq$hi){return $s[$lo]};$w=$r-$lo;return ($s[$lo]*(1-$w))+($s[$hi]*$w)}
"GPTOPT CapFrameX Hitch Analysis $Stamp" | Out-File $Report
try{
    $item=Get-Item -LiteralPath (Resolve-Path -LiteralPath $Path)
    if($item.PSIsContainer){$csvs=@(gci $item.FullName -Recurse -File -Filter *.csv)}
    elseif($item.Extension -ieq '.csv'){$csvs=@($item)}
    elseif($item.Extension -ieq '.zip'){$TempDir=Join-Path ([IO.Path]::GetTempPath()) "GPTOPT-CFX-$([guid]::NewGuid().ToString('N'))";mkdir $TempDir|Out-Null;Expand-Archive $item.FullName $TempDir -Force;$csvs=@(gci $TempDir -Recurse -File -Filter *.csv)}
    else{throw 'Use CSV, folder, or ZIP.'}
    Log ACTION "Found $($csvs.Count) CSV file(s)."
    $out=foreach($csv in $csvs){
        $rows=@(Import-Csv $csv.FullName);if($rows.Count-lt10){Log WARN "Skip $($csv.Name): too few rows";continue}
        $s=$rows[0]
        $ftc=Col $s @('MsBetweenPresents','msBetweenPresents','Frametime','FrameTime','msBetweenDisplayChange','MsBetweenDisplayChange')
        if(!$ftc){Log WARN "Skip $($csv.Name): no frametime column";continue}
        $tc=Col $s @('TimeInSeconds','Time (s)','Time')
        $cc=Col $s @('CpuActive','MsCpuActive','CPUActive','CPU Active','msCpuActive')
        $gc=Col $s @('GpuActive','MsGpuActive','GPUActive','GPU Active','msGpuActive')
        $pc=Col $s @('MsInPresentAPI','msInPresentAPI','PresentAPI')
        $dc=Col $s @('Dropped','DroppedPresent','WasDropped')
        $frames=for($i=0;$i-lt$rows.Count;$i++){ $r=$rows[$i];$ft=Num $r.$ftc;if($null-ne$ft){[pscustomobject]@{Csv=$csv.Name;Index=$i;Time=if($tc){Num $r.$tc}else{$null};FrameMs=$ft;Cpu=if($cc){Num $r.$cc}else{$null};Gpu=if($gc){Num $r.$gc}else{$null};Present=if($pc){Num $r.$pc}else{$null};Dropped=if($dc){[string]$r.$dc}else{''}}}}
        $fts=[double[]]@($frames.FrameMs);$h=@($frames|?{$_.FrameMs-ge$HitchMs});$o10=@($frames|?{$_.FrameMs-ge10});$o16=@($frames|?{$_.FrameMs-ge16.67});$drop=@($frames|?{$_.Dropped-match'true|1|yes'})
        $cx=@();$cy=@();$gx=@();$gy=@();$px=@();$py=@();foreach($x in $h){if($null-ne$x.Cpu){$cx+=$x.FrameMs;$cy+=$x.Cpu};if($null-ne$x.Gpu){$gx+=$x.FrameMs;$gy+=$x.Gpu};if($null-ne$x.Present){$px+=$x.FrameMs;$py+=$x.Present}}
        $ccor=Corr ([double[]]$cx) ([double[]]$cy);$gcor=Corr ([double[]]$gx) ([double[]]$gy);$pcor=Corr ([double[]]$px) ([double[]]$py);$avgGpu=if($gy){($gy|measure -Average).Average}else{$null}
        $class='Unknown / insufficient telemetry';$conf='Low'
        if($h.Count-eq0){$class='No hitches above threshold';$conf='High'}
        elseif($null-ne$ccor -and $ccor-ge0.95 -and $null-ne$avgGpu -and $avgGpu-lt($HitchMs*.75)){$class='Application CPU frame-production stall';$conf='High'}
        elseif($null-ne$gcor -and $gcor-ge0.85 -and $null-ne$avgGpu -and $avgGpu-ge($HitchMs*.75)){$class='GPU work / GPU-bound hitch';$conf='Medium'}
        elseif($null-ne$pcor -and $pcor-ge0.70){$class='Present / display queue stall';$conf='Medium'}
        $hcsv=Join-Path $LogDir "$($csv.BaseName)-hitches-over-$HitchMs-ms.csv";$h|sort FrameMs -Descending|Export-Csv $hcsv -NoTypeInformation
        Log PASS "$($csv.Name): $class ($conf), hitches>$HitchMs=$($h.Count), >10=$($o10.Count), >16.67=$($o16.Count), max=$(($fts|measure -Maximum).Maximum) ms"
        $top=$h|sort FrameMs -Descending|select -First 5
        foreach($t in $top){Add-Content $Report ("  t={0}s frame={1:N3} cpu={2} gpu={3} present={4}" -f $t.Time,$t.FrameMs,$t.Cpu,$t.Gpu,$t.Present)}
        [pscustomobject]@{Csv=$csv.FullName;Frames=$frames.Count;AvgFPS=1000/(($fts|measure -Average).Average);P01FPS=1000/(Pctl $fts 99.9);MaxFrameMs=($fts|measure -Maximum).Maximum;Hitches=$h.Count;Over10Ms=$o10.Count;Over1667Ms=$o16.Count;Dropped=$drop.Count;CpuCorr=$ccor;GpuCorr=$gcor;PresentCorr=$pcor;Classification=$class;Confidence=$conf;HitchCsv=$hcsv}
    }
    $out|Export-Csv $Summary -NoTypeInformation
    Log PASS "Report saved: $Report"
    Log PASS "Summary saved: $Summary"
} finally {
    if($TempDir -and (Test-Path $TempDir)){Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue}
}
