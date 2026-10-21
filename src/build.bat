@echo off
title Build ProksiFi v2.0
cd /d "%~dp0"

echo ==============================================================
echo    COMPILING PROKSIFI v2.0 VIA POWERSHELL BUILD.PS1
echo ==============================================================
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0build.ps1"
pause
