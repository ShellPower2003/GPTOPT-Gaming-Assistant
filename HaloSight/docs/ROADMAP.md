# HaloSight Roadmap

## v0.4 current
- External session start/stop/status/report workflow
- Copies CapFrameX/video evidence generated during session
- Logs Windows gaming state, services, timer, processes, device errors, audio devices
- Packages upload zip for ChatGPT analysis
- Leaves browser/Halo/Steam/RTSS/Afterburner/CapFrameX alone
- Faster single-pass evidence discovery with upload safety caps
- ffmpeg path resolution and x264 fallback when NVENC is unavailable
- WPF GUI wrapper for start, stop, status, report, upload-folder open, and zip-path copy
- Default/user settings split with GUI editing and validation
- Smoke test and GitHub Actions coverage

## v0.5 next
- Parse CapFrameX CSV/JSON automatically into report summary
- PresentMon ETW integration if PresentMon.exe is present in tools
- OBS WebSocket start/stop support
- ffmpeg auto-install helper optional, not forced

## v0.6
- Video frame sampler: scoreboard/death/fight screenshots
- Audio/Sonar glitch detector using audiodg/process spikes
- Overlay/process interference scoring

## hard no
- No game injection
- No memory reading
- No input manipulation
- No anti-cheat bypass
