@echo off
echo Enabling Quality Mode...
powercfg -setactive SCHEME_BALANCED
sc start SysMain
sc config SysMain start=auto
pause