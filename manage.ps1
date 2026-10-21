# ==============================================================================
# ProksiFi v2.0 - Service Management Console
# ==============================================================================
param(
    [ValidateSet("status", "start", "stop", "restart", "test", "info", "logs", "diag", "help")]
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
    Write-Host "`n=== PROKSIFI SERVICE STATUS ===" -ForegroundColor Cyan
    if ($svc) {
        $color = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  Service: $($svc.DisplayName) ($serviceName)"
        Write-Host "  Status:  $($svc.Status)" -ForegroundColor $color
        Write-Host "  Startup: $($svc.StartType)"
    } else {
        Write-Host "  Service $serviceName is NOT installed!" -ForegroundColor Red
        Write-Host "  Run install.bat or .\install.ps1 as Administrator." -ForegroundColor Yellow
        return
    }

    $tunAdapter = Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tunAdapter) {
        Write-Host "  Adapter: $($tunAdapter.Name) (Status: $($tunAdapter.Status))" -ForegroundColor Green
    } else {
        Write-Host "  Adapter: ProksiFiTUN is not active" -ForegroundColor Gray
    }
}

function Show-Info {
    $profilePath = "$env:ProgramData\ProksiFi\device.json"
    if (-not (Test-Path $profilePath)) {
        $profilePath = "$env:ProgramData\AntigravityBypass\device.json"
    }
    if (Test-Path $profilePath) {
        $p = Get-Content -Path $profilePath -Raw | ConvertFrom-Json
        Write-Host "`n=== CLIENT BINDING INFO ===" -ForegroundColor Cyan
        Write-Host "  HWID:       $($p.HWID)"
        Write-Host "  Short ID:   $($p.ShortHWID)"
        Write-Host "  Email:      $($p.Email)"
        Write-Host "  UUID:       $($p.UUID)"
        Write-Host "  Server:     $($p.Reality.ServerHost):$($p.Reality.ServerPort)"
        Write-Host "  SNI:        $($p.Reality.ServerName)"
        Write-Host "  gRPC Svc:   $($p.Reality.ServiceName)"
    } else {
        Write-Host "Profile device.json not found." -ForegroundColor Yellow
    }
}

function Test-ConnectionQuality {
    Write-Host "`n=== ROUTING AND GEO TESTING ===" -ForegroundColor Cyan

    Write-Host "1. Testing Google Gemini (via 127.0.0.1:7890)..." -NoNewline
    try {
        $res = & curl.exe -s -o NUL -w "%{http_code}" -m 7 -x http://127.0.0.1:7890 https://gemini.google.com
        if ($res -eq "200" -or $res -eq "302") {
            Write-Host " [OK] ($res)" -ForegroundColor Green
        } else {
            Write-Host " [Code: $res]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    Write-Host "2. Testing Google AI Studio API..." -NoNewline
    try {
        $res = & curl.exe -s -o NUL -w "%{http_code}" -m 7 -x http://127.0.0.1:7890 https://generativelanguage.googleapis.com
        if ($res -eq "404" -or $res -eq "200" -or $res -eq "403") {
            Write-Host " [OK] Endpoint reachable ($res)" -ForegroundColor Green
        } else {
            Write-Host " [Code: $res]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    Write-Host "3. Testing Direct Local Traffic (Yandex)..." -NoNewline
    try {
        $res = & curl.exe -s -o NUL -w "%{http_code}" -m 5 https://ya.ru
        if ($res -eq "200" -or $res -eq "302") {
            Write-Host " [OK] Direct without proxy ($res)" -ForegroundColor Green
        } else {
            Write-Host " [Code: $res]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    Write-Host "4. Testing IP & Country (ipinfo.io)..." -NoNewline
    try {
        $ipJson = & curl.exe -s -m 7 -x http://127.0.0.1:7890 https://ipinfo.io
        $ipObj = $ipJson | ConvertFrom-Json
        if ($ipObj.country -eq "DE") {
            Write-Host " [OK] IP: $($ipObj.ip), Country: $($ipObj.country) ($($ipObj.city))" -ForegroundColor Green
        } else {
            Write-Host " [NOTICE] Country: $($ipObj.country), IP: $($ipObj.ip)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    Write-Host "5. Testing Telegram (https://t.me)..." -NoNewline
    try {
        $tgCode = & curl.exe -s -o NUL -w "%{http_code}" -m 7 -x http://127.0.0.1:7890 https://t.me
        if ($tgCode -eq "200" -or $tgCode -eq "302") {
            Write-Host " [OK] Telegram reachable ($tgCode)" -ForegroundColor Green
        } else {
            Write-Host " [Code: $tgCode]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }
}

function Show-Logs {
    $serviceLog = "$env:ProgramData\ProksiFi\logs\service.log"
    if (-not (Test-Path $serviceLog)) {
        $serviceLog = "$env:ProgramData\AntigravityBypass\logs\service.log"
    }
    $errLog = "$env:ProgramData\ProksiFi\logs\service.err.log"
    $installLog = "$env:ProgramData\ProksiFi\logs\install.log"

    Write-Host "`n=== PROKSIFI SERVICE EVENT LOGS ($serviceLog) ===" -ForegroundColor Cyan
    if (Test-Path $serviceLog) {
        if ($Follow) {
            Write-Host "Streaming live logs (Press Ctrl+C to exit)..." -ForegroundColor Yellow
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
        Write-Host "Service log file not created yet (service might not have run)." -ForegroundColor Yellow
    }

    if (Test-Path $errLog) {
        $errContent = Get-Content -Path $errLog -Tail 15 -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($errContent -and $errContent.Count -gt 0) {
            Write-Host "`n=== СИСТЕМНЫЙ ЖУРНАЛ ОШИБОК ($errLog) ===" -ForegroundColor Red
            foreach ($e in $errContent) {
                Write-Host "  $e" -ForegroundColor Red
            }
        }
    }

    if (Test-Path $installLog) {
        Write-Host "`n=== RECENT INSTALL LOGS ($installLog) ===" -ForegroundColor Cyan
        Get-Content -Path $installLog -Tail 10 -Encoding UTF8 -ErrorAction SilentlyContinue
    }
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
        Start-Service -Name $serviceName
        Show-Status
    }
    "stop" {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "User")
        Stop-Service -Name $serviceName -Force
        Show-Status
    }
    "restart" {
        Restart-Service -Name $serviceName -Force
        Show-Status
    }
    "test" {
        Test-ConnectionQuality
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
        Write-Host "Usage: .\manage.ps1 [status|start|stop|restart|test|diag|info|logs]" -ForegroundColor Yellow
    }
}
