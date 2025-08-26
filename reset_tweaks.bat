@echo off
echo Resetting all tweaks to default...
powercfg -setactive SCHEME_BALANCED
sc config SysMain start=auto
sc start SysMain
sc config DiagTrack start=auto
sc start DiagTrack
pause