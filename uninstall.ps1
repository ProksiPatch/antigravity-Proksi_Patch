# ==============================================================================
# ProksiFi v2.0 - Complete Service Uninstaller & Deep System Wiper
# ==============================================================================
[CmdletBinding()]
param(
    [switch]$FullClean,
    [int]$CallerPID = 0
)

# Set UTF-8 output encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Check Administrator Privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[UAC] Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -FullClean") -Verb RunAs
    exit
}

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (Test-Path "$ScriptDir\modules\browser-hardening.ps1") {
    . "$ScriptDir\modules\browser-hardening.ps1"
}

Write-Host "==========================================================" -ForegroundColor Red
Write-Host "  PROKSIFI v2.0 — ПОЛНАЯ И УМНАЯ ОЧИСТКА СИСТЕМЫ        " -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red

$serviceNames = @("ProksiFiService", "AntigravityBypassService")
$programDirs = @("C:\Program Files\ProksiFi", "C:\Program Files\AntigravityBypass")
$dataDirs = @("$env:ProgramData\ProksiFi", "$env:ProgramData\AntigravityBypass")

# -----------------------------------------------------------------------------
# Шаг 1: Остановка служб и принудительное завершение всех процессов
# -----------------------------------------------------------------------------
Write-Host "`n[1/6] Остановка служб и завершение связанных процессов..." -ForegroundColor Yellow

# Остановка WinSW служб
foreach ($pDir in $programDirs) {
    $serviceExe = Join-Path $pDir "service.exe"
    if (Test-Path -LiteralPath $serviceExe) {
        & $serviceExe stop 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
}

foreach ($sName in $serviceNames) {
    $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $sName -Force -ErrorAction SilentlyContinue
    }
}

# Принудительное завершение ядра и вспомогательных процессов
& taskkill.exe /F /IM core.exe /T 2>&1 | Out-Null
& taskkill.exe /F /IM service.exe /T 2>&1 | Out-Null
& taskkill.exe /F /IM mihomo.exe /T 2>&1 | Out-Null

$lingeringProcesses = Get-Process -Name "core", "service", "mihomo" -ErrorAction SilentlyContinue
foreach ($p in $lingeringProcesses) {
    try {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Завершение агента трея ProksiFi_Tray.exe (кроме вызывающего процесса)
$proksiProcesses = Get-Process -Name "ProksiFi*" -ErrorAction SilentlyContinue
foreach ($pp in $proksiProcesses) {
    if ($CallerPID -gt 0 -and $pp.Id -eq $CallerPID) { continue }
    if ($pp.Id -eq $PID) { continue }
    try {
        Write-Host "  Закрытие интерфейса трея (PID $($pp.Id))..." -ForegroundColor Gray
        Stop-Process -Id $pp.Id -Force -ErrorAction SilentlyContinue
    } catch {}
}

Write-Host "  [OK] Все процессы ядра и интерфейса завершены." -ForegroundColor Green

# -----------------------------------------------------------------------------
# Шаг 2: Удаление служб Windows
# -----------------------------------------------------------------------------
Write-Host "`n[2/6] Удаление служб Windows..." -ForegroundColor Yellow
foreach ($pDir in $programDirs) {
    $serviceExe = Join-Path $pDir "service.exe"
    if (Test-Path -LiteralPath $serviceExe) {
        & $serviceExe uninstall 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
}

foreach ($sName in $serviceNames) {
    if (Get-Service -Name $sName -ErrorAction SilentlyContinue) {
        & sc.exe delete $sName 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
}
Write-Host "  [OK] Службы Windows успешно разрегистрированы." -ForegroundColor Green

# -----------------------------------------------------------------------------
# Шаг 3: Полная очистка виртуальных сетевых адаптеров WinTun и IP-адресов
# -----------------------------------------------------------------------------
Write-Host "`n[3/6] Очистка виртуальных сетевых адаптеров WinTun..." -ForegroundColor Yellow
try {
    # Сброс IP-адреса с виртуального интерфейса
    & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
    & netsh.exe interface ipv4 delete address name="AntigravityTUN" addr=172.19.0.1 2>&1 | Out-Null
    Get-NetIPAddress -InterfaceAlias "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# Отключение и сброс адаптеров
Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "  [OK] Сетевой стек и виртуальные адаптеры полностью очищены." -ForegroundColor Green

# -----------------------------------------------------------------------------
# Шаг 4: Сброс системного прокси, политик браузеров и переменных Antigravity
# -----------------------------------------------------------------------------
Write-Host "`n[4/6] Восстановление сетевых настроек Windows и переменных окружения..." -ForegroundColor Yellow
try {
    # Восстановление QUIC в Chrome/Edge/Yandex
    if (Get-Command Remove-BrowserQuicPolicy -ErrorAction SilentlyContinue) {
        Remove-BrowserQuicPolicy
    }

    # Отключение системного прокси
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value "" -Type String -Force -ErrorAction SilentlyContinue

    # Сброс переменной Antigravity IDE
    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "User")
    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "Machine")
    Remove-Item Env:\AG_LS_PROXY -ErrorAction SilentlyContinue

    # Удаление из автозапуска
    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ProksiFi_Tray" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ProksiFi_Tray" -Force -ErrorAction SilentlyContinue

    # Очистка DNS кэша Windows
    & ipconfig.exe /flushdns 2>&1 | Out-Null

    Write-Host "  [OK] Системный прокси отключен, AG_LS_PROXY сброшен, DNS кэш очищен." -ForegroundColor Green
} catch {
    Write-Warning "Предупреждение при сбросе сетевых настроек: $_"
}

# -----------------------------------------------------------------------------
# Шаг 5: Удаление ярлыков и автозапуска
# -----------------------------------------------------------------------------
Write-Host "`n[5/6] Удаление ярлыков из меню Пуск и Рабочего стола..." -ForegroundColor Yellow
$shortcutPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\ProksiFi*",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ProksiFi*",
    "$env:PUBLIC\Desktop\ProksiFi*.lnk",
    "$env:USERPROFILE\Desktop\ProksiFi*.lnk"
)
foreach ($sp in $shortcutPaths) {
    Get-Item -Path $sp -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Ярлыки удалены." -ForegroundColor Green

# -----------------------------------------------------------------------------
# Шаг 6: Удаление файлов программы и данных (Program Files и ProgramData)
# -----------------------------------------------------------------------------
Write-Host "`n[6/6] Полное удаление директорий программы и профилей..." -ForegroundColor Yellow
Set-Location -LiteralPath $env:TEMP

foreach ($pDir in $programDirs) {
    if (Test-Path -LiteralPath $pDir) {
        Remove-Item -LiteralPath $pDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Удалена папка программы: $pDir" -ForegroundColor Green
    }
}

foreach ($dDir in $dataDirs) {
    if (Test-Path -LiteralPath $dDir) {
        Remove-Item -LiteralPath $dDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Удалена папка профилей и данных: $dDir" -ForegroundColor Green
    }
}

# Очистка временных файлов установщика
$tempSetup = Join-Path $env:TEMP "ProksiFi_Setup"
if (Test-Path -LiteralPath $tempSetup) {
    Remove-Item -LiteralPath $tempSetup -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  ПРОГРАММА ПОЛНОСТЬЮ И БЕЗ СЛЕДА УДАЛЕНА ИЗ СИСТЕМЫ!" -ForegroundColor Green
Write-Host "  Система находится в исходном чистом состоянии." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
