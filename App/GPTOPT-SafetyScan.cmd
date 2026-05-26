@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -NoExit -File ".\Run-GPTOPT.ps1" -Mode safety
exit /b %ERRORLEVEL%
