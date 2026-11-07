@echo off
chcp 65001 >nul
title Установка ProksiFi v2.0
echo ==========================================================
echo   ЗАПУСК УСТАНОВКИ PROKSIFI ОТ ИМЕНИ АДМИНИСТРАТОРА...
echo ==========================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0install.ps1\"\"' -Verb RunAs"
