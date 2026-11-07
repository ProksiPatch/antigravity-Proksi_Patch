# ==============================================================================
# ProksiFi v2.0 - Service Management & Quick Repair Console
# ==============================================================================
param(
    [ValidateSet("status", "start", "stop", "restart", "install", "test", "ag", "info", "logs", "diag", "fix", "upload", "help")]
    [string]$Action = "status",
    [int]$Lines = 30,
    [switch]$Follow
)

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$diagModule = Join-Path $ScriptDir "modules\diagnostics.ps1"
if (Test-Path $diagModule) {
    . $diagModule
}

$serviceName = "ProksiFiService"
if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
    if (Get-Service -Name "AntigravityBypassService" -ErrorAction SilentlyContinue) {
        $serviceName = "AntigravityBypassService"
    }
}

function Show-Status {
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    Write-Host "`n=== СТАТУС СЛУЖБЫ PROKSIFI ===" -ForegroundColor Cyan
    if ($svc) {
        $color = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  Служба:  $($svc.DisplayName) ($serviceName)"
        Write-Host "  Статус:  $($svc.Status)" -ForegroundColor $color
        Write-Host "  Запуск:  $($svc.StartType)"
    } else {
        Write-Host "  Служба $serviceName НЕ установлена в системе!" -ForegroundColor Red
        Write-Host "  Запустите установку от имени Администратора." -ForegroundColor Yellow
        return
    }

    $core = Get-Process -Name "core" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($core) {
        $ram = [Math]::Round($core.WorkingSet64 / 1MB, 1)
        Write-Host "  Ядро:    core.exe (PID: $($core.Id), RAM: $ram МБ)" -ForegroundColor Green
    } else {
        Write-Host "  Ядро:    core.exe не запущен" -ForegroundColor Red
    }

    $tunAdapter = Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tunAdapter) {
        Write-Host "  Адаптер: $($tunAdapter.Name) (Статус: $($tunAdapter.Status))" -ForegroundColor Green
    } else {
        Write-Host "  Адаптер: ProksiFiTUN не активен" -ForegroundColor Gray
    }

    $agProxy = [System.Environment]::GetEnvironmentVariable("AG_LS_PROXY", "User")
    if ($agProxy -eq "http://127.0.0.1:7890") {
        Write-Host "  AG_LS:   $agProxy (Корректно)" -ForegroundColor Green
    } elseif ($agProxy) {
        Write-Host "  AG_LS:   $agProxy (ВНИМАНИЕ: подменен сторонним патчером!)" -ForegroundColor Yellow
    }
}

function Show-Info {
    $profilePath = "$env:ProgramData\ProksiFi\device.json"
    if (-not (Test-Path $profilePath)) {
        $profilePath = "$env:ProgramData\AntigravityBypass\device.json"
    }
    if (Test-Path $profilePath) {
        $p = Get-Content -Path $profilePath -Raw | ConvertFrom-Json
        Write-Host "`n=== ПАРАМЕТРЫ КЛИЕНТСКОГО ПРОФИЛЯ ===" -ForegroundColor Cyan
        Write-Host "  HWID:       $($p.HWID)"
        Write-Host "  Short ID:   $($p.ShortHWID)"
        Write-Host "  Email:      $($p.Email)"
        Write-Host "  UUID:       $($p.UUID)"
        Write-Host "  Сервер:     $($p.Reality.ServerHost):$($p.Reality.ServerPort)"
        Write-Host "  SNI:        $($p.Reality.ServerName)"
        Write-Host "  gRPC:       $($p.Reality.ServiceName)"
    } else {
        Write-Host "Файл профиля device.json не найден." -ForegroundColor Yellow
    }
}

function Test-AntigravitySuite {
    if (Get-Command Invoke-ProksiFiDiagnostics -ErrorAction SilentlyContinue) {
        Invoke-ProksiFiDiagnostics
    }
}

function Test-ConnectionQuality {
    if (Get-Command Invoke-ProksiFiDiagnostics -ErrorAction SilentlyContinue) {
        Invoke-ProksiFiDiagnostics
    }
}

function Show-Logs {
    $logDir = "$env:ProgramData\ProksiFi\logs"
    if (-not (Test-Path $logDir)) {
        $logDir = "$env:ProgramData\AntigravityBypass\logs"
    }

    $serviceLog = Join-Path $logDir "service.log"
    $errLog = Join-Path $logDir "service.err.log"

    Write-Host "`n=== ЖУРНАЛ СОБЫТИЙ PROKSIFI ($serviceLog) ===" -ForegroundColor Cyan
    if (Test-Path $serviceLog) {
        if ($Follow) {
            Write-Host "Трансляция логов в реальном времени (Ctrl+C для выхода)..." -ForegroundColor Yellow
            Get-Content -Path $serviceLog -Tail $Lines -Wait
        } else {
            $logLines = Get-Content -Path $serviceLog -Tail $Lines -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $logLines) {
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
        }
    } else {
        Write-Host "Файл service.log пока пуст." -ForegroundColor Yellow
    }

    if (Test-Path $errLog) {
        $errContent = Get-Content -Path $errLog -Tail 15 -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($errContent -and $errContent.Count -gt 0) {
            Write-Host "`n=== ЖУРНАЛ ОШИБОК ($errLog) ===" -ForegroundColor Red
            foreach ($e in $errContent) {
                Write-Host "  $e" -ForegroundColor Red
            }
        }
    }
}

function Invoke-QuickFix {
    Write-Host "`n=== БЫСТРОЕ АВТОИСПРАВЛЕНИЕ СИСТЕМЫ И СЛУЖБЫ ===" -ForegroundColor Cyan
    Write-Host "1. Остановка службы $serviceName..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue

    Write-Host "2. Принудительное завершение конфликтующих процессов и патчеров..." -ForegroundColor Yellow
    & taskkill.exe /F /IM core.exe /T 2>&1 | Out-Null
    $conflicts = Get-Process -Name "core", "mihomo", "ag_dns", "AG_Unlocker", "AG_2.26.0", "ag_proxy", "happd", "HappProxy", "HiddifyCli" -ErrorAction SilentlyContinue
    foreach ($cp in $conflicts) {
        try { Stop-Process -Id $cp.Id -Force -ErrorAction SilentlyContinue } catch {}
    }

    Write-Host "3. Сброс и очистка виртуального адаптера WinTun..." -ForegroundColor Yellow
    try {
        & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
        & netsh.exe interface ipv4 delete address name="AntigravityTUN" addr=172.19.0.1 2>&1 | Out-Null
        Get-NetIPAddress -InterfaceAlias "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "4. Восстановление переменной AG_LS_PROXY и системного прокси..." -ForegroundColor Yellow
    $proxyOverride = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>;*.ru;*.su;*.xn--p1ai"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "127.0.0.1:7890" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value $proxyOverride -Type String -Force -ErrorAction SilentlyContinue

    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "User")
    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "Machine")
    $env:AG_LS_PROXY = "http://127.0.0.1:7890"

    # Перезапуск языкового сервера Antigravity, чтобы он сразу подхватил порт 7890
    $lsProcs = Get-Process -Name "language_server" -ErrorAction SilentlyContinue
    if ($lsProcs) {
        Write-Host "   -> Перезапуск процесса language_server.exe для применения прокси 7890..." -ForegroundColor Gray
        foreach ($lsp in $lsProcs) {
            try { Stop-Process -Id $lsp.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    Write-Host "5. Запуск службы $serviceName..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 600
    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Show-Status
    Write-Host "`n[OK] Быстрое восстановление выполнено успешно!" -ForegroundColor Green
}

switch ($Action) {
    "status" {
        Show-Status
    }
    "info" {
        Show-Info
    }
    "start" {
        $proxyOverride = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>;*.ru;*.su;*.xn--p1ai"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "127.0.0.1:7890" -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value $proxyOverride -Type String -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "User")
        [Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "Machine")
        Start-Service -Name $serviceName
        Show-Status
    }
    "stop" {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "User")
        [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "Machine")
        Stop-Service -Name $serviceName -Force
        try {
            & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
        } catch {}
        Show-Status
    }
    "restart" {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        & taskkill.exe /F /IM core.exe 2>&1 | Out-Null
        try {
            & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
            Get-NetIPAddress -InterfaceAlias "ProksiFiTUN*" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        } catch {}
        Start-Sleep -Milliseconds 600
        Start-Service -Name $serviceName
        Show-Status
    }
    "install" {
        $instScript = Join-Path $ScriptDir "install.ps1"
        if (Test-Path $instScript) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $instScript
        } else {
            Write-Host "Скрипт установки install.ps1 не найден в $ScriptDir." -ForegroundColor Red
        }
    }
    "fix" {
        Invoke-QuickFix
    }
    "test" {
        if (Get-Command Invoke-ProksiFiDiagnostics -ErrorAction SilentlyContinue) {
            Invoke-ProksiFiDiagnostics
        } else {
            Write-Host "Модуль диагностики не найден." -ForegroundColor Red
        }
    }
    "ag" {
        if (Get-Command Invoke-ProksiFiDiagnostics -ErrorAction SilentlyContinue) {
            Invoke-ProksiFiDiagnostics
        } else {
            Write-Host "Модуль диагностики не найден." -ForegroundColor Red
        }
    }
    "upload" {
        if (Get-Command Send-ProksiFiLogsToServer -ErrorAction SilentlyContinue) {
            $null = Send-ProksiFiLogsToServer -Interactive
        } else {
            Write-Host "Функция отправки логов не найдена." -ForegroundColor Red
        }
    }
    "diag" {
        if (Get-Command Invoke-ProksiFiDiagnostics -ErrorAction SilentlyContinue) {
            Invoke-ProksiFiDiagnostics
        } else {
            Write-Host "Модуль диагностики не найден." -ForegroundColor Red
        }
    }
    "logs" {
        Show-Logs
    }
    "help" {
        Write-Host "Использование: .\manage.ps1 [status|start|stop|restart|fix|test|ag|diag|upload|info|logs]" -ForegroundColor Yellow
    }
}
