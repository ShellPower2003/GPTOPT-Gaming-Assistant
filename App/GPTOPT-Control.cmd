@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File ".\Run-GPTOPT.ps1" -Mode guided
exit /b %ERRORLEVEL%
