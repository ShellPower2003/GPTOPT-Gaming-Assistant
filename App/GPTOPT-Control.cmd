@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -NoExit -File ".\Scripts\Invoke-GPTOPTAppGUI.ps1"
exit /b %ERRORLEVEL%
