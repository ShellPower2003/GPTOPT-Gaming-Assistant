$SettingsScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsRootDir = Split-Path -Parent $SettingsScriptDir
$SettingsConfigDir = Join-Path $SettingsRootDir 'config'
$SettingsDefaultPath = Join-Path $SettingsConfigDir 'halosight.default.json'
$SettingsUserPath = Join-Path $SettingsConfigDir 'halosight.user.json'

function Copy-HaloSightObject {
    param([Parameter(Mandatory=$true)]$InputObject)
    return $InputObject | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Merge-HaloSightObject {
    param(
        [Parameter(Mandatory=$true)]$Base,
        [Parameter(Mandatory=$true)]$Overlay
    )
    $merged = Copy-HaloSightObject $Base
    foreach($prop in $Overlay.PSObject.Properties){
        $baseProp = $merged.PSObject.Properties[$prop.Name]
        $overlayValue = $prop.Value
        if($baseProp -and $baseProp.Value -is [pscustomobject] -and $overlayValue -is [pscustomobject]){
            $baseProp.Value = Merge-HaloSightObject $baseProp.Value $overlayValue
        }elseif($baseProp){
            $baseProp.Value = $overlayValue
        }else{
            $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $overlayValue
        }
    }
    return $merged
}

function Get-HaloSightConfig {
    if(!(Test-Path -LiteralPath $SettingsDefaultPath)){
        throw "Missing default config: $SettingsDefaultPath"
    }
    if(!(Test-Path -LiteralPath $SettingsUserPath)){
        New-Item -ItemType Directory -Force -Path $SettingsConfigDir | Out-Null
        Copy-Item -LiteralPath $SettingsDefaultPath -Destination $SettingsUserPath -Force
    }
    $default = Get-Content -Raw -LiteralPath $SettingsDefaultPath | ConvertFrom-Json
    $user = Get-Content -Raw -LiteralPath $SettingsUserPath | ConvertFrom-Json
    return Merge-HaloSightObject $default $user
}

function Save-HaloSightConfig {
    param([Parameter(Mandatory=$true)]$Config)
    New-Item -ItemType Directory -Force -Path $SettingsConfigDir | Out-Null
    $Config | ConvertTo-Json -Depth 20 | Out-File -FilePath $SettingsUserPath -Encoding UTF8
    return Get-HaloSightConfig
}

function Reset-HaloSightConfig {
    if(!(Test-Path -LiteralPath $SettingsDefaultPath)){
        throw "Missing default config: $SettingsDefaultPath"
    }
    New-Item -ItemType Directory -Force -Path $SettingsConfigDir | Out-Null
    Copy-Item -LiteralPath $SettingsDefaultPath -Destination $SettingsUserPath -Force
    return Get-HaloSightConfig
}

function Test-HaloSightConfig {
    param($Config = (Get-HaloSightConfig))
    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if([string]::IsNullOrWhiteSpace($Config.SessionRoot)){ $errors.Add('SessionRoot is required.') }
    if(@($Config.SearchRoots).Count -lt 1){ $errors.Add('At least one evidence folder is required.') }
    if([int]$Config.Evidence.MaxFiles -lt 1){ $errors.Add('Evidence.MaxFiles must be at least 1.') }
    if([double]$Config.Evidence.MaxFileMB -lt 1){ $errors.Add('Evidence.MaxFileMB must be at least 1.') }
    if(@($Config.WatchedProcesses).Count -lt 1){ $warnings.Add('No watched processes are configured.') }
    if(@($Config.WatchedServices).Count -lt 1){ $warnings.Add('No watched services are configured.') }
    foreach($rootRaw in @($Config.SearchRoots)){
        $root = [Environment]::ExpandEnvironmentVariables($rootRaw)
        if(!(Test-Path -LiteralPath $root)){ $warnings.Add("Evidence folder does not exist yet: $root") }
    }

    [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = @($errors)
        Warnings = @($warnings)
        DefaultPath = $SettingsDefaultPath
        UserPath = $SettingsUserPath
    }
}
