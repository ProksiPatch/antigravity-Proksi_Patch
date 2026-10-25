@echo off
title ProksiFi v2.0 Installer
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
