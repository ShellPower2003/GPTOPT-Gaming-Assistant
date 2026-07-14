@echo off
setlocal
cd /d "%~dp0"
title GPTOPT Gaming Assistant

where pwsh.exe >nul 2>&1
if %ERRORLEVEL%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1" -Mode gui
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1" -Mode gui
)

set "GPTOPT_EXIT=%ERRORLEVEL%"
if not "%GPTOPT_EXIT%"=="0" (
  echo.
  echo GPTOPT failed to start. Exit code: %GPTOPT_EXIT%
  echo.
  pause
)
exit /b %GPTOPT_EXIT%
