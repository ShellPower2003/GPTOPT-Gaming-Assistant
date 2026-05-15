@echo off
setlocal
cd /d "%~dp0"

:menu
cls
echo GPTOPT Launcher
echo.
echo 1. HaloSight GUI
echo 2. HaloSight Start
echo 3. HaloSight Stop + Build Upload
echo 4. HaloSight Status
echo 5. HaloSight Settings
echo 6. Run Smoke Test
echo 7. Exit
echo.
set /p choice=Select an option: 

if "%choice%"=="1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\scripts\HaloSightGUI.ps1"
if "%choice%"=="2" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\scripts\HaloSight.ps1" -Mode start
if "%choice%"=="3" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\scripts\HaloSight.ps1" -Mode stop
if "%choice%"=="4" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\scripts\HaloSight.ps1" -Mode status
if "%choice%"=="5" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\scripts\HaloSightGUI.ps1" -OpenSettings
if "%choice%"=="6" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HaloSight\tests\smoke_test.ps1"
if "%choice%"=="7" exit /b 0

echo.
pause
goto menu
