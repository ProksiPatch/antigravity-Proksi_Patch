@echo off
title ProksiFi v2.0 Service Manager
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage.ps1"
pause
