@echo off
echo Enabling Esports Performance Mode...
powercfg -setactive SCHEME_MIN
sc stop SysMain
sc config SysMain start= disabled
sc stop DiagTrack
sc config DiagTrack start= disabled
pause