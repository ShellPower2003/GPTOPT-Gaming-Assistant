@echo off
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Start-GPTOPT.ps1"
if errorlevel 1 (echo GPTOPT audit failed.& pause& exit /b 1)
