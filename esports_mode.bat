@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scripts\Invoke-GPTOPTProfile.ps1" -Mode ApplyEsports
pause
