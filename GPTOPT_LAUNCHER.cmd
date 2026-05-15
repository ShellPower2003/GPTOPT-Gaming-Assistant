@echo off
setlocal
cd /d "%~dp0"

rem GPTOPT is GUI-first. Start/stop/status/settings are handled inside the GUI.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1" -Mode gui

if errorlevel 1 (
  echo.
  echo GPTOPT GUI exited with an error.
  pause
)
