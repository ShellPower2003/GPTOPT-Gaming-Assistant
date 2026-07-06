@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -NoExit -File ".\Scripts\Test-GPTOPTSafety.ps1"
exit /b %ERRORLEVEL%
