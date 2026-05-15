# HaloSight Troubleshooting

## No upload zip was created

Run `HaloSight_STATUS.cmd` and confirm a session exists. If no session is active, run `HaloSight_START.cmd`, capture a short test, then run `HaloSight_STOP.cmd`.

## Evidence files are missing

Open Settings and confirm your evidence folders include the folders where CapFrameX, OBS, NVIDIA, or other capture tools write files.

## Video compression is skipped

Compression requires `ffmpeg.exe` on `PATH` or in the configured optional tool path. Evidence copying still works when ffmpeg is unavailable.

## Settings look wrong

Open Settings and select `Reset Defaults`, or delete `config\halosight.user.json`; HaloSight will recreate it from defaults.

## Validate the package

Run:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests\smoke_test.ps1
```
