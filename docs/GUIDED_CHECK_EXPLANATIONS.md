# Guided Check Explanations

Guided Mode should not show raw optimization labels without explanation. Each readiness check needs to answer seven questions:

1. What is this?
2. Why does it matter for gaming feel?
3. What does good look like?
4. What is bad or worth review?
5. What is the safest action?
6. What is the risk?
7. How can the user undo it?

The machine-readable catalog lives at `Knowledge/check-explanations.json`.

## Display refresh rate

Checks whether Windows is actually running the gaming display at the intended resolution and refresh rate. For the user's Omen OLED baseline, good means 3840x2160 at 240 Hz. If the monitor is accidentally running at 60 Hz, 120 Hz, or the wrong display is primary, Halo will feel heavier regardless of game settings.

## Power plan

Checks whether Windows is using a performance-oriented plan. Balanced is not always broken, but for competitive testing it adds another variable. Good means High Performance, Ultimate Performance, or a known GPTOPT gaming plan.

## Timer resolution

Checks whether the low-latency timer holder is active. This matters for frame pacing tools, polling behavior, capture utilities, and consistency. Good means the timer is held at 0.5 ms during the gaming session.

## USB selective suspend

Checks whether Windows can power down USB devices. For wired controller and headset paths, this should be disabled on AC power so the controller/audio chain does not randomly wake or suspend mid-session.

## HAGS

Checks Hardware-accelerated GPU scheduling. This is not universally good or bad. For the current RTX 5080 Halo baseline, HAGS on is the expected state unless a controlled test proves otherwise.

## MPO

Checks Multiplane Overlay state. MPO can interact with HDR, overlays, VRR, borderless fullscreen, and capture tools. For this user's current baseline, MPO disabled is expected. This should be changed only with backup and reboot guidance.

## Game Mode

Checks Windows Game Mode. For the current Halo baseline, Game Mode should be on. The UI should show Good when it matches the profile, not Review just because it is a Windows setting.

## Game DVR / background capture

Checks whether Windows background capture is disabled. Dedicated capture tools should be intentional. Background recording should not be quietly active during competitive testing.

## DWM tweak leftovers

Checks for old registry tweaks that try to disable or alter Desktop Window Manager. Modern Windows games and borderless fullscreen depend on DWM behavior. Bad old tweaks can create stutter, login/display problems, HDR weirdness, or bad input feel.

## Halo Infinite config

Checks the Halo settings file against the selected profile without blindly rewriting it. Good means the expected resolution, 100 percent scale, VSync off, HDR preference, and 960/960 min-target frame settings when that profile is selected. The tool must not change unrelated Halo JSON fields.

## RTSS Halo profile

Checks whether RTSS is capping Halo correctly. For the user's baseline, Good means the Halo profile exists, `FramerateLimit` is 240, and `ApplicationDetectionLevel` is 2. Detection merely being nonzero is too loose.

## Steam state

Checks that Steam is available for the Steam Halo install. Xbox/Gaming Services should not be the default troubleshooting path unless login or launch specifically requires it.

## Flydigi controller stack

Checks Flydigi SpaceStation, GameControllerService, and device presence. This stack should not be killed as bloat because it affects the user's Vader controller behavior and stick tuning.

## SteelSeries Sonar

Checks SteelSeries/Sonar process, service, or audio-device presence. Sonar is required for this user's headset route, so the tool must not label it as generic bloat or recommend killing it.

## Pending reboot

Splits reboot state into real action versus review. Windows Update or component servicing reboot means Action. Pending file rename/delete operations only means Review. A Gaming Services cleanup entry by itself should not block Ready to Play.

## Background load

Shows heavy background CPU/GPU/disk/memory users. Firefox can be ignored when it is being used for ChatGPT troubleshooting. The tool must not kill RTSS, Afterburner, Flydigi, Sonar, Steam, or capture tools needed for the session.

## Required UI behavior

Guided Mode should display the short explanation on each card and put raw evidence behind Show Details. Advanced labels such as HAGS, MPO, DWM, CBS, RTSS, and PendingFileRenameOperations should never appear without human-readable meaning nearby.
