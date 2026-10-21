@echo off
title ProksiFi v2.0 Uninstaller
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -FullClean
pause
