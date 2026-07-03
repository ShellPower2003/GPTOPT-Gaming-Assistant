function Expand-GPTOPTPathHint {
    param([string]$Path)

    if (-not $Path) { return $null }
    [Environment]::ExpandEnvironmentVariables($Path)
}

function Resolve-GPTOPTSessionAppPath {
    param(
        [object]$App,
        [scriptblock]$PathProbe = { param($Path) Test-Path -LiteralPath $Path },
        [scriptblock]$CommandProbe = {
            param($Name)
            $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { return [string]$command.Source }
            return $null
        }
    )

    foreach ($name in @($App.executableNames)) {
        $resolved = & $CommandProbe ([string]$name)
        if ($resolved) { return [string]$resolved }
    }

    foreach ($hint in @($App.pathHints)) {
        $candidate = Expand-GPTOPTPathHint -Path ([string]$hint)
        if ($candidate -and (& $PathProbe $candidate)) { return $candidate }
    }

    return $null
}

function Test-GPTOPTSessionAppRunning {
    param(
        [object]$App,
        [scriptblock]$ProcessProbe = {
            param([string[]]$Names)
            foreach ($name in $Names) {
                if (Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1) {
                    return $true
                }
            }
            return $false
        }
    )

    [bool](& $ProcessProbe @($App.processNames))
}

function Get-GPTOPTSessionStackPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Catalog,
        [Parameter(Mandatory)]
        [string]$ProfileId,
        [scriptblock]$ProcessProbe = {
            param([string[]]$Names)
            foreach ($name in $Names) {
                if (Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1) {
                    return $true
                }
            }
            return $false
        },
        [scriptblock]$PathProbe = { param($Path) Test-Path -LiteralPath $Path },
        [scriptblock]$CommandProbe = {
            param($Name)
            $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { return [string]$command.Source }
            return $null
        }
    )

    $profile = @($Catalog.profiles | Where-Object { [string]$_.profileId -eq $ProfileId } | Select-Object -First 1)
    if ($profile.Count -eq 0) {
        $profile = @($Catalog.profiles | Where-Object { [string]$_.profileId -eq 'generic.shooter' } | Select-Object -First 1)
    }
    if ($profile.Count -eq 0) { return @() }

    $required = @($profile[0].required)
    $recommended = @($profile[0].recommended)
    $appIds = @($required + $recommended | Select-Object -Unique)
    $plan = New-Object System.Collections.Generic.List[object]

    foreach ($appId in $appIds) {
        $app = $Catalog.apps | Where-Object { [string]$_.id -eq [string]$appId } | Select-Object -First 1
        if (-not $app) { continue }

        $role = if ($required -contains [string]$app.id) { 'Required' } else { 'Recommended' }
        $running = Test-GPTOPTSessionAppRunning -App $app -ProcessProbe $ProcessProbe
        $path = $null
        $status = 'NotFound'

        if ($running) {
            $status = 'Running'
        } elseif ([string]$app.launchPolicy -eq 'manual') {
            $status = 'Manual'
        } else {
            $path = Resolve-GPTOPTSessionAppPath -App $app -PathProbe $PathProbe -CommandProbe $CommandProbe
            if ($path) { $status = 'ReadyToStart' }
        }

        $plan.Add([pscustomobject]@{
            Id = [string]$app.id
            DisplayName = [string]$app.displayName
            Role = $role
            Status = $status
            ExecutablePath = $path
            LaunchPolicy = [string]$app.launchPolicy
            Why = [string]$app.why
            Risk = [string]$app.risk
            Undo = [string]$app.undo
        })
    }

    @($plan.ToArray())
}

function Invoke-GPTOPTSessionStackPlan {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object[]]$Plan,
        [scriptblock]$Launcher = {
            param($Path)
            Start-Process -FilePath $Path | Out-Null
        }
    )

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Plan)) {
        if ([string]$item.Status -ne 'ReadyToStart' -or -not $item.ExecutablePath) {
            $results.Add([pscustomobject]@{
                Id = [string]$item.Id
                DisplayName = [string]$item.DisplayName
                Outcome = 'Skipped'
                Detail = [string]$item.Status
            })
            continue
        }

        try {
            if ($PSCmdlet.ShouldProcess([string]$item.ExecutablePath, "Start $($item.DisplayName)")) {
                & $Launcher ([string]$item.ExecutablePath)
                $results.Add([pscustomobject]@{
                    Id = [string]$item.Id
                    DisplayName = [string]$item.DisplayName
                    Outcome = 'Started'
                    Detail = [string]$item.ExecutablePath
                })
            } else {
                $results.Add([pscustomobject]@{
                    Id = [string]$item.Id
                    DisplayName = [string]$item.DisplayName
                    Outcome = 'Preview'
                    Detail = [string]$item.ExecutablePath
                })
            }
        } catch {
            $results.Add([pscustomobject]@{
                Id = [string]$item.Id
                DisplayName = [string]$item.DisplayName
                Outcome = 'Failed'
                Detail = $_.Exception.Message
            })
        }
    }

    @($results.ToArray())
}
