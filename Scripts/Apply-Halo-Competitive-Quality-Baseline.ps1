$ErrorActionPreference='Stop'
Clear-Host
Write-Host "`n=== APPLY HALO COMPETITIVE QUALITY BASELINE ===" -ForegroundColor Cyan
Write-Host "Backs up Halo config. No reboot. No driver registry hacks.`n" -ForegroundColor Green

function OK($m){Write-Host "[OK]  $m" -ForegroundColor Green}
function DOIT($m){Write-Host "[DO]  $m" -ForegroundColor Yellow}
function WARN($m){Write-Host "[WARN] $m" -ForegroundColor Yellow}
function Set-HaloJsonValue($json,$name,$value){
    if($json.PSObject.Properties.Name -contains $name){
        $json.$name.value = $value
        OK "$name = $value"
    } else {
        WARN "Missing Halo key: $name"
    }
}

$settingsDir = Join-Path $env:LOCALAPPDATA 'HaloInfinite\Settings'
$spec = Join-Path $settingsDir 'SpecControlSettings.json'
if(!(Test-Path $spec)){Write-Host "Missing: $spec" -ForegroundColor Red; exit 1}

$backup = "$spec.backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $spec $backup -Force
OK "Backup created: $backup"

DOIT "Reading Halo config"
$json = Get-Content $spec -Raw | ConvertFrom-Json

# Match active 4K/240 display while keeping the user's 960 min/target dynamic-res model.
Set-HaloJsonValue $json 'spec_control_windowed_display_resolution_x' 3840
Set-HaloJsonValue $json 'spec_control_windowed_display_resolution_y' 2160
Set-HaloJsonValue $json 'spec_control_resolution_scale' 100
Set-HaloJsonValue $json 'spec_control_ui_resolution_scale' 100
Set-HaloJsonValue $json 'spec_control_minimum_framerate' 960
Set-HaloJsonValue $json 'spec_control_target_framerate' 960
Set-HaloJsonValue $json 'spec_control_vsync' 0
Set-HaloJsonValue $json 'cap_frame_rate_on_loss_of_focus' 0
Set-HaloJsonValue $json 'mute_audio_on_loss_of_focus' 0

# Competitive clarity / low distraction.
Set-HaloJsonValue $json 'chromatic_aberration_enabled' 0
Set-HaloJsonValue $json 'bloom_enabled' 0
Set-HaloJsonValue $json 'parallax_enabled' 0
Set-HaloJsonValue $json 'spec_control_motion_blur' 0
Set-HaloJsonValue $json 'spec_control_screen_shake' 0
Set-HaloJsonValue $json 'spec_control_exposure' 0
Set-HaloJsonValue $json 'spec_control_screen_effects' 0
Set-HaloJsonValue $json 'spec_control_speed_lines' 0

# Preserve competitive visual shape: high assets/LOD/simulation, low expensive effects.
Set-HaloJsonValue $json 'spec_control_asset_category_level' 'Ultra'
Set-HaloJsonValue $json 'spec_control_hlod' 'Ultra'
Set-HaloJsonValue $json 'spec_control_animation_quality' 'Max'
Set-HaloJsonValue $json 'spec_control_simulation_quality' 'Ultra'
Set-HaloJsonValue $json 'spec_control_reflections' 'Off'
Set-HaloJsonValue $json 'spec_control_volumetric_fog' 'Off'
Set-HaloJsonValue $json 'spec_control_raytraced_sun_shadows' 'Off'
Set-HaloJsonValue $json 'spec_control_flocks' 'Off'

DOIT "Writing Halo config"
$json | ConvertTo-Json -Depth 20 | Set-Content -Path $spec -Encoding UTF8
OK "Halo config written"

DOIT "Setting live tool priorities if running"
$prio=@{
 'RTSS'='High'
 'MSIAfterburner'='AboveNormal'
 'steam'='AboveNormal'
}
foreach($p in $prio.Keys){
    Get-Process $p -ErrorAction SilentlyContinue | ForEach-Object {
        try{$_.PriorityClass=$prio[$p]; OK "$p priority = $($prio[$p])"}catch{WARN "Could not set $p priority"}
    }
}

Write-Host "`nRecommended benchmark run:" -ForegroundColor Cyan
Write-Host "- Close Discord for clean capture"
Write-Host "- RTSS cap 240"
Write-Host "- Halo Reflex ON or ON+Boost; test both"
Write-Host "- Do one fixed route, then compare frametime/1%/0.1% lows"
Write-Host "`nDone. No reboot." -ForegroundColor Green
