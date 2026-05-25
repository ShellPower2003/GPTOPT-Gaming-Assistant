@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -NoExit -File ".\Run-GPTOPT.ps1" -Mode recommend -Context NormalGaming
exit /b %ERRORLEVEL%
