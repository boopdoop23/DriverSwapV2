@echo off
title Assetto Corsa Driver Swap - Loading...

:: Minimize this window immediately
powershell -Command "(New-Object -ComObject Shell.Application).MinimizeAll()"

:: Check if PowerShell script exists
if not exist "%~dp0MainCode.ps1" (
    echo Error: MainCode.ps1 not found in the same folder.
    echo Please ensure both files are in the same directory.
    pause
    exit /b 1
)

:: Launch PowerShell GUI
echo Starting Assetto Corsa Driver Swap Tool...
echo Please wait for the GUI to load...
echo.
echo Note: You can minimize this window - the GUI will open separately.

powershell -ExecutionPolicy Bypass -File "%~dp0MainCode.ps1"

:: Close automatically when GUI closes
exit /b
