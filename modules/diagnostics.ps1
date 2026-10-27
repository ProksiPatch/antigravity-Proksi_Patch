# ==============================================================================
# ProksiFi v2.0 - Advanced Diagnostics & Error Recognition Engine
# Automated health-checks, log scanning, root-cause analysis, and step-by-step fixes
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:ErrorSignatures = @(
    @{
        Id          = "PORT_IN_USE"
        Severity    = "CRITICAL"
        Title       = "Конфликт сетевых портов (127.0.0.1:7890 занят)"
        Patterns    = @(
            "bind: address already in use",
            "listen tcp 127.0.0.1:7890: bind",
            "Only one usage of each socket address",
            "failed to start inbound:.*7890"
        )
        Description = "Локальный порт 7890 уже занят другой запущенной программой."
        Cause       = "В системе параллельно запущен другой прокси/VPN клиент (Clash, V2RayN, Nekoray, Amnezia или зависший процесс core.exe)."
        Solution    = "1. Закройте сторонние прокси-клиенты через Диспетчер задач.`n2. Нажмите правой кнопкой на значок ProksiFi в трее и выберите 'Перезапустить службу'."
    },
    @{
        Id          = "HANDSHAKE_OR_TIME_SKEW"
        Severity    = "CRITICAL"
        Title       = "Сбой Reality TLS рукопожатия / Рассинхронизация времени"
        Patterns    = @(
            "remote error: tls: handshake failure",
            "tls: handshake message out of sequence",
            "tls: bad certificate",
            "certificate has expired"
        )
        Description = "Клиент не может завершить защищенное рукопожатие VLESS Reality с сервером во Франкфурте."
        Cause       = "Системное время Windows отличается от реального мирового времени более чем на 60 секунд (Reality строго требует совпадения времени), либо антивирус подменяет SSL-сертификаты."
        Solution    = "1. Откройте: 'Параметры Windows' -> 'Время и язык' -> 'Дата и время' -> нажмите кнопку 'Синхронизировать'.`n2. Если включен антивирус (Kaspersky, Dr.Web, ESET) — временно отключите 'Проверку HTTPS/защищенных соединений'."
    },
    @{
        Id          = "WINTUN_ADAPTER_ERROR"
        Severity    = "CRITICAL"
        Title       = "Ошибка виртуального сетевого адаптера WinTun"
        Patterns    = @(
            "CreateTun: failed to open wintun adapter",
            "failed to create adapter",
            "WintunCreateAdapter failed",
            "wintun: failed to register",
            "access is denied.*wintun"
        )
        Description = "Ядро не смогло создать виртуальный туннельный адаптер ProksiFiTUN в Windows."
        Cause       = "Блокировка установки сетевого драйвера сторонним антивирусом/брандмауэром или повреждение сетевого стека."
        Solution    = "1. Добавьте папку 'C:\Program Files\ProksiFi' в исключения антивируса.`n2. Выберите в меню трея 'Перезапустить службу' или перезапустите установщик от имени Администратора."
    },
    @{
        Id          = "VPS_NETWORK_TIMEOUT"
        Severity    = "WARNING"
        Title       = "Сетевой таймаут соединения к серверу (Франкфурт VPS)"
        Patterns    = @(
            "dial tcp.*i/o timeout",
            "connect: connection timed out",
            "dial tcp.*2083.*i/o timeout",
            "read: connection reset by peer"
        )
        Description = "Пакеты до зарубежного сервера теряются или не доходят вовремя."
        Cause       = "Временные проблемы с внешним интернет-каналом вашего провайдера (потери пакетов) или кратковременная фильтрация зарубежных подсетей ТСПУ/РКН."
        Solution    = "1. Проверьте общее подключение к интернету.`n2. Если интернет работает — обычно фильтрация длится 1-3 минуты. Выберите в трее 'Перезапустить службу'."
    },
    @{
        Id          = "CORE_NOT_RUNNING"
        Severity    = "CRITICAL"
        Title       = "Ядро маршрутизации не отвечает (Порт 127.0.0.1:7890 закрыт)"
        Patterns    = @(
            "No connection could be made because the target machine actively refused it",
            "connection refused.*127.0.0.1:7890",
            "Failed to connect to 127.0.0.1 port 7890"
        )
        Description = "Система пытается отправить запрос в локальный прокси, но ядро core.exe не запущено."
        Cause       = "Служба ProksiFiService остановлена пользователем либо была завершена операционной системой."
        Solution    = "Кликните правой кнопкой по значку ProksiFi в трее и выберите 'Включить обход' (или 'Перезапустить службу')."
    },
    @{
        Id          = "DNS_RESOLUTION_FAILURE"
        Severity    = "WARNING"
        Title       = "Сбой разрешения доменных имен (DNS Error)"
        Patterns    = @(
            "dns: failed to resolve",
            "SERVFAIL",
            "NXDOMAIN",
            "dns query timed out",
            "exchange.*failed.*dns"
        )
        Description = "Не удается преобразовать доменное имя сайта в IP-адрес."
        Cause       = "Локальный DNS-провайдер блокирует запросы или наблюдается сбой встроенного DoH-резолвера."
        Solution    = "Перезапустите службу в трее. ProksiFi автоматически переподключит защищенный Google DoH (8.8.8.8) через туннель."
    },
    @{
        Id          = "USER_REJECTED"
        Severity    = "CRITICAL"
        Title       = "Ключ доступа отклонен сервером 3X-UI"
        Patterns    = @(
            "user not found",
            "rejected by server",
            "invalid user uuid",
            "inbound connection rejected"
        )
        Description = "Сервер во Франкфурте отклонил профиль подключения."
        Cause       = "Профиль или UUID был удален/сброшен на сервере."
        Solution    = "Выберите в меню трея 'Полное удаление программы', затем запустите установку заново для автоматического получения нового ключа."
    }
)

function Test-TimeSync {
    try {
        $raw = w32tm /stripchart /computer:pool.ntp.org /samples:1 /dataonly 2>$null
        $lastLine = $raw | Where-Object { $_ -match "[-+]\d+\.\d+s" } | Select-Object -Last 1
        if ($lastLine -match "([-+]\d+\.\d+)s") {
            $offset = [double]$matches[1]
            return [PSCustomObject]@{
                Success = $true
                OffsetSeconds = $offset
                IsCritical = ([Math]::Abs($offset) -gt 45)
            }
        }
    } catch { }
    return [PSCustomObject]@{
        Success = $false
        OffsetSeconds = 0
        IsCritical = $false
    }
}

function Invoke-ProksiFiDiagnostics {
    param(
        [string]$LogDir = "$env:ProgramData\ProksiFi\logs",
        [int]$MaxLogLines = 300
    )

    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "     PROKSIFI v2.0 — ИНТЕЛЛЕКТУАЛЬНАЯ ДИАГНОСТИКА И АНАЛИЗ ОШИБОК      " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    # -------------------------------------------------------------------------
    # 1. LIVE SYSTEM HEALTH CHECKS
    # -------------------------------------------------------------------------
    Write-Host "`n[1/4] ПРОВЕРКА СОСТОЯНИЯ СИСТЕМЫ И СЛУЖБЫ:" -ForegroundColor Yellow

    $serviceName = "ProksiFiService"
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $svc) {
        $svc = Get-Service -Name "AntigravityBypassService" -ErrorAction SilentlyContinue
        if ($svc) { $serviceName = "AntigravityBypassService" }
    }

    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "  ✔ Служба Windows:      $serviceName (Работает)" -ForegroundColor Green
    } elseif ($svc) {
        Write-Host "  ✖ Служба Windows:      $serviceName ($($svc.Status))" -ForegroundColor Red
    } else {
        Write-Host "  ✖ Служба Windows:      НЕ УСТАНОВЛЕНА" -ForegroundColor Red
    }

    # Core process check
    $coreProc = Get-Process -Name "core" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($coreProc) {
        $ramMb = [Math]::Round($coreProc.WorkingSet64 / 1MB, 1)
        Write-Host "  ✔ Процесс ядра:        core.exe (PID: $($coreProc.Id), Память: $ramMb МБ)" -ForegroundColor Green
    } else {
        Write-Host "  ✖ Процесс ядра:        core.exe НЕ ЗАПУЩЕН" -ForegroundColor Red
    }

    # Port 7890 check
    $portConn = Get-NetTCPConnection -LocalPort 7890 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portConn) {
        if ($coreProc -and $portConn.OwningProcess -eq $coreProc.Id) {
            Write-Host "  ✔ Порт 127.0.0.1:7890: Открыт и слушается процессом core.exe" -ForegroundColor Green
        } else {
            Write-Host "  ✖ Порт 127.0.0.1:7890: ЗАНЯТ ЧУЖИМ ПРОЦЕССОМ (PID: $($portConn.OwningProcess))!" -ForegroundColor Red
        }
    } else {
        if ($svc -and $svc.Status -eq "Running") {
            Write-Host "  ✖ Порт 127.0.0.1:7890: Не слушается (ядро не запустило mixed inbound)" -ForegroundColor Red
        } else {
            Write-Host "  • Порт 127.0.0.1:7890: Закрыт (служба остановлена)" -ForegroundColor Gray
        }
    }

    # System Proxy check
    $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($proxySettings -and $proxySettings.ProxyEnable -eq 1) {
        Write-Host "  ✔ Системный прокси:    ВКЛЮЧЕН ($($proxySettings.ProxyServer))" -ForegroundColor Green
    } else {
        Write-Host "  • Системный прокси:    ВЫКЛЮЧЕН (Прямой доступ)" -ForegroundColor Gray
    }

    # WinTun adapter check
    $tunAdapter = Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tunAdapter -and $tunAdapter.Status -eq "Up") {
        Write-Host "  ✔ Туннельный адаптер:  $($tunAdapter.Name) (Статус: Up)" -ForegroundColor Green
    } elseif ($tunAdapter) {
        Write-Host "  ⚠ Туннельный адаптер:  $($tunAdapter.Name) (Статус: $($tunAdapter.Status))" -ForegroundColor Yellow
    } else {
        Write-Host "  • Туннельный адаптер:  ProksiFiTUN не создан (работает режим системного прокси)" -ForegroundColor Gray
    }

    # Windows Time Sync Check
    $timeCheck = Test-TimeSync
    if ($timeCheck.Success) {
        if ($timeCheck.IsCritical) {
            Write-Host "  ✖ Время Windows:       РАССИНХРОНИЗАЦИЯ ($($timeCheck.OffsetSeconds) сек)! Reality handshake может сбоить!" -ForegroundColor Red
        } else {
            Write-Host "  ✔ Время Windows:       Точное (смещение $($timeCheck.OffsetSeconds) сек относительно NTP)" -ForegroundColor Green
        }
    } else {
        Write-Host "  • Время Windows:       Проверка NTP пропущена (нет ответа NTP)" -ForegroundColor Gray
    }

    # -------------------------------------------------------------------------
    # 2. LOG SCANNING & AUTOMATED ERROR RECOGNITION
    # -------------------------------------------------------------------------
    Write-Host "`n[2/4] АНАЛИЗ ЖУРНАЛОВ И РАСПОЗНАВАНИЕ ОШИБОК:" -ForegroundColor Yellow

    $serviceLog = Join-Path $LogDir "service.log"
    $errLog = Join-Path $LogDir "service.err.log"
    $wrapperLog = Join-Path $LogDir "service.wrapper.log"

    $allLogLines = @()
    if (Test-Path $serviceLog) {
        $allLogLines += (Get-Content -Path $serviceLog -Tail $MaxLogLines -Encoding UTF8 -ErrorAction SilentlyContinue)
    }
    if (Test-Path $errLog) {
        $allLogLines += (Get-Content -Path $errLog -Tail 100 -Encoding UTF8 -ErrorAction SilentlyContinue)
    }
    if (Test-Path $wrapperLog) {
        $allLogLines += (Get-Content -Path $wrapperLog -Tail 50 -Encoding UTF8 -ErrorAction SilentlyContinue)
    }

    $detectedErrors = @{}

    foreach ($line in $allLogLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        foreach ($sig in $script:ErrorSignatures) {
            foreach ($pattern in $sig.Patterns) {
                if ($line -match $pattern) {
                    if (-not $detectedErrors.ContainsKey($sig.Id)) {
                        $detectedErrors[$sig.Id] = @{
                            Signature = $sig
                            Count = 1
                            SampleLine = $line.Trim()
                        }
                    } else {
                        $detectedErrors[$sig.Id].Count++
                        $detectedErrors[$sig.Id].SampleLine = $line.Trim()
                    }
                    break
                }
            }
        }
    }

    if ($detectedErrors.Count -eq 0) {
        Write-Host "  ✔ [ОТЛИЧНО] В журналах работы критических ошибок не обнаружено!" -ForegroundColor Green
        Write-Host "    Проанализировано строк логов: $($allLogLines.Count)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ ВНИМАНИЕ: Обнаружено распознанных проблем: $($detectedErrors.Count)`n" -ForegroundColor Red

        foreach ($key in $detectedErrors.Keys) {
            $err = $detectedErrors[$key]
            $sig = $err.Signature

            $badgeColor = if ($sig.Severity -eq "CRITICAL") { "Red" } else { "Yellow" }
            Write-Host "  ┌──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
            Write-Host "  │ [$($sig.Severity)] $($sig.Title) (Зафиксировано: $($err.Count) раз)" -ForegroundColor $badgeColor
            Write-Host "  ├──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
            Write-Host "  │ 📌 Что произошло: $($sig.Description)" -ForegroundColor White
            Write-Host "  │ 🔍 Первопричина:   $($sig.Cause)" -ForegroundColor Cyan
            Write-Host "  │ 💡 Что делать:     $($sig.Solution)" -ForegroundColor Green
            Write-Host "  │ 📄 Пример из лога: $($err.SampleLine)" -ForegroundColor DarkGray
            Write-Host "  └──────────────────────────────────────────────────────────────────`n" -ForegroundColor $badgeColor
        }
    }

    # -------------------------------------------------------------------------
    # 3. LIVE ROUTING & TARGET REACHABILITY TEST
    # -------------------------------------------------------------------------
    Write-Host "[3/4] ЭКСПРЕСС-ПРОВЕРКА КАНАЛОВ ОБХОДА:" -ForegroundColor Yellow

    # Gemini
    Write-Host "  1. Google Gemini (https://gemini.google.com)..." -NoNewline
    try {
        $res = & curl.exe -s -o NUL -w "%{http_code}" -m 6 -x http://127.0.0.1:7890 https://gemini.google.com
        if ($res -eq "200" -or $res -eq "302") {
            Write-Host " [OK] (HTTP $res)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $res]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # Yandex Direct
    Write-Host "  2. Прямой российский трафик (ya.ru)..." -NoNewline
    try {
        $res = & curl.exe -s -o NUL -w "%{http_code}" -m 5 https://ya.ru
        if ($res -eq "200" -or $res -eq "302") {
            Write-Host " [OK] (Direct без прокси)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $res]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # IP & Country
    Write-Host "  3. Проверка геопозиции (ipinfo.io)..." -NoNewline
    try {
        $ipJson = & curl.exe -s -m 6 -x http://127.0.0.1:7890 https://ipinfo.io
        $ipObj = $ipJson | ConvertFrom-Json
        if ($ipObj.country -eq "DE") {
            Write-Host " [OK] $($ipObj.ip), $($ipObj.city) ($($ipObj.country))" -ForegroundColor Green
        } else {
            Write-Host " [NOTICE] $($ipObj.country), IP: $($ipObj.ip)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # -------------------------------------------------------------------------
    # 4. RECENT LOG STREAM WITH SEMANTIC COLORING
    # -------------------------------------------------------------------------
    Write-Host "`n[4/4] ПОСЛЕДНИЕ СОБЫТИЯ ЖУРНАЛА (ЦВЕТОВАЯ РАЗМЕТКА):" -ForegroundColor Yellow

    if (Test-Path $serviceLog) {
        $recent = Get-Content -Path $serviceLog -Tail 20 -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($line in $recent) {
            if ($line -match "ERROR|FATAL|panic|failed") {
                Write-Host "  $line" -ForegroundColor Red
            } elseif ($line -match "WARN|WARNING|timeout") {
                Write-Host "  $line" -ForegroundColor Yellow
            } elseif ($line -match "dns: exchanged") {
                Write-Host "  $line" -ForegroundColor Cyan
            } elseif ($line -match "outbound/vless") {
                Write-Host "  $line" -ForegroundColor Green
            } elseif ($line -match "outbound/direct") {
                Write-Host "  $line" -ForegroundColor DarkGray
            } else {
                Write-Host "  $line" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  Файл service.log пока пуст или служба еще не запускалась." -ForegroundColor Gray
    }

    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host "     ДИАГНОСТИКА ЗАВЕРШЕНА                                             " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
}

# Run diagnostics if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ProksiFiDiagnostics
}
