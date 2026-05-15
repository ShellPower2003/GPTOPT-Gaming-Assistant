@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GPTOPT.ps1" -Mode gui
set "GPTOPT_EXIT=%ERRORLEVEL%"

if not "%GPTOPT_EXIT%"=="0" (
  echo.
  echo GPTOPT GUI exited with error code %GPTOPT_EXIT%.
  echo.
  pause
  exit /b %GPTOPT_EXIT%
)
