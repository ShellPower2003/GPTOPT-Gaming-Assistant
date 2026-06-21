function ConvertTo-GPTOPTRating {
    param([object]$Value)

    if ($null -eq $Value) { return $null }
    $match = [regex]::Match([string]$Value, '^\s*([1-5])(?:\s|$)')
    if (-not $match.Success) { return $null }
    return [int]$match.Groups[1].Value
}

function Get-GPTOPTSessionInsights {
    [CmdletBinding()]
    param(
        [object[]]$Reviews = @(),
        [string]$ProfileId = '',
        [int]$WindowSize = 30
    )

    $matching = @($Reviews | Where-Object {
        $null -ne $_ -and
        (-not $ProfileId -or [string]$_.ProfileId -eq $ProfileId)
    } | Sort-Object {
        try { [datetime]$_.RecordedAt } catch { [datetime]::MinValue }
    } -Descending | Select-Object -First $WindowSize)

    $ratings = @($matching | ForEach-Object { ConvertTo-GPTOPTRating -Value $_.Rating } | Where-Object { $null -ne $_ })
    $inputSamples = @($matching | Where-Object { [string]$_.InputFeel })
    $audioSamples = @($matching | Where-Object { [string]$_.AudioConfidence -and [string]$_.AudioConfidence -ne 'Not assessed' })
    $warmupSamples = @($matching | Where-Object { [string]$_.WarmupOutcome })

    $averageRating = if ($ratings.Count) {
        [math]::Round((($ratings | Measure-Object -Average).Average), 2)
    } else {
        $null
    }
    $consistentInputRate = if ($inputSamples.Count) {
        [math]::Round((@($inputSamples | Where-Object { [string]$_.InputFeel -eq 'Consistent' }).Count / $inputSamples.Count), 2)
    } else { $null }
    $audioIssueRate = if ($audioSamples.Count) {
        [math]::Round((@($audioSamples | Where-Object { [string]$_.AudioConfidence -in @('Wrong route', 'Hard to locate') }).Count / $audioSamples.Count), 2)
    } else { $null }
    $warmupReadyRate = if ($warmupSamples.Count) {
        [math]::Round((@($warmupSamples | Where-Object { [string]$_.WarmupOutcome -eq 'Ready' }).Count / $warmupSamples.Count), 2)
    } else { $null }

    $summary = New-Object System.Collections.Generic.List[string]
    $recommendations = New-Object System.Collections.Generic.List[string]

    if ($matching.Count -eq 0) {
        $summary.Add('No completed session reviews for this profile yet.')
        $recommendations.Add('Save three post-session reviews to unlock profile-specific trends.')
    } else {
        $summary.Add("Evidence window: $($matching.Count) session review(s).")
        if ($null -ne $averageRating) { $summary.Add("Average session rating: $averageRating / 5.") }
        if ($null -ne $consistentInputRate) { $summary.Add("Consistent input: $([math]::Round($consistentInputRate * 100))%.") }
        if ($null -ne $audioIssueRate) { $summary.Add("Audio routing/localization issues: $([math]::Round($audioIssueRate * 100))%.") }
        if ($null -ne $warmupReadyRate) { $summary.Add("Warmup marked ready: $([math]::Round($warmupReadyRate * 100))%.") }

        if ($matching.Count -lt 3) {
            $recommendations.Add("Log $([math]::Max(0, 3 - $matching.Count)) more session review(s) before treating patterns as reliable.")
        }
        if ($null -ne $consistentInputRate -and $inputSamples.Count -ge 3 -and $consistentInputRate -lt 0.6) {
            $recommendations.Add('Prioritize input consistency next session: confirm one input path, then use the same sensitivity and warmup.')
        }
        if ($null -ne $audioIssueRate -and $audioSamples.Count -ge 3 -and $audioIssueRate -ge 0.3) {
            $recommendations.Add('Verify the game and communications audio routes before queueing; audio issues recur in this profile.')
        }
        if ($null -ne $warmupReadyRate -and $warmupSamples.Count -ge 3 -and $warmupReadyRate -lt 0.6) {
            $recommendations.Add('Adjust the warmup before changing system settings; the current routine often does not produce a ready result.')
        }

        if ($ratings.Count -ge 6) {
            $recentAverage = (@($ratings | Select-Object -First 3) | Measure-Object -Average).Average
            $priorAverage = (@($ratings | Select-Object -Skip 3 -First 3) | Measure-Object -Average).Average
            $trend = [math]::Round(($recentAverage - $priorAverage), 2)
            $summary.Add("Recent rating trend: $trend versus the prior three sessions.")
            if ($trend -le -0.5) {
                $recommendations.Add('Recent ratings declined. Keep the setup fixed for one session and isolate one gameplay or hardware variable.')
            }
        }

        if ($recommendations.Count -eq 0) {
            $recommendations.Add('No recurring setup problem is strong enough to prioritize. Keep the current baseline and continue logging sessions.')
        }
    }

    [pscustomobject]@{
        ProfileId = $ProfileId
        SessionCount = $matching.Count
        AverageRating = $averageRating
        ConsistentInputRate = $consistentInputRate
        AudioIssueRate = $audioIssueRate
        WarmupReadyRate = $warmupReadyRate
        SummaryLines = @($summary.ToArray())
        Recommendations = @($recommendations.ToArray())
        EvidenceWindow = @($matching)
    }
}
