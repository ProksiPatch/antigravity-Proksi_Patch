# ==============================================================================
# ProksiFi v2.0 - Advanced Diagnostics & Error Recognition Engine (Smart AI & Network Auditor)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:ErrorSignatures = @(
    @{
        Id          = "ANTIGRAVITY_RESOURCE_EXHAUSTED"
        Severity    = "WARNING"
        Title       = "Исчерпан лимит/квота модели Google в Antigravity IDE (Код -8)"
        Patterns    = @(
            "RESOURCE_EXHAUSTED",
            "Error ID:.*-8",
            "quota exceeded",
            "rate limit exceeded",
            "429 Too Many Requests"
        )
        Description = "Google временно ограничил генерацию ответов из-за исчерпания суточной или минутной квоты на вашем Google-аккаунте."
        Cause       = "В Antigravity выбрана модель с высоким бюджетом рассуждений (например, Gemini 3.8 Flash High), для которой действуют строгие лимиты Google. Прокси-сервер ProksiFi при этом работает на 100% исправно!"
        Solution    = "1. Внизу окна Antigravity IDE переключите модель на 'Gemini 3.8 Flash (Low / Medium)'.`n2. Либо смените Google-аккаунт в настройках Antigravity.`n3. Либо подождите сброса лимита (обычно от 1 до 60 минут)."
    },
    @{
        Id          = "ANTIGRAVITY_DEADLINE_EXCEEDED"
        Severity    = "WARNING"
        Title       = "Превышено время ожидания ответа модели в Antigravity (Код -4)"
        Patterns    = @(
            "DEADLINE_EXCEEDED",
            "Error ID:.*-4"
        )
        Description = "Сервер Google не успел обработать запрос за установленное время."
        Cause       = "Слишком большой контекст файлов или слишком длинный запрос."
        Solution    = "Используйте команду /compact для сжатия контекста или разбейте задачу на более мелкие шаги."
    },
    @{
        Id          = "ANTIGRAVITY_UNAVAILABLE"
        Severity    = "WARNING"
        Title       = "Серверы Google AI временно перегружены (Код -14)"
        Patterns    = @(
            "UNAVAILABLE",
            "Error ID:.*-14",
            "503 Service Unavailable"
        )
        Description = "Серверы Gemini в европейском дата-центре испытывают высокую нагрузку."
        Cause       = "Временные неполадки на стороне инфраструктуры Google."
        Solution    = "Подождите 15-30 секунд и отправьте запрос повторно."
    },
    @{
        Id          = "WINTUN_ADAPTER_ERROR"
        Severity    = "CRITICAL"
        Title       = "Конфликт или сбой виртуального адаптера WinTun"
        Patterns    = @(
            "CreateTun: failed to open wintun adapter",
            "failed to create adapter",
            "WintunCreateAdapter failed",
            "wintun: failed to register",
            "access is denied.*wintun",
            "The object already exists",
            "Cannot create a file when that file already exists"
        )
        Description = "Ядро маршрутизации не смогло инициализировать адаптер ProksiFiTUN (IP 172.19.0.1 уже занят или адаптер заблокирован)."
        Cause       = "Предыдущий процесс был завершен некорректно, либо антивирус заблокировал сетевой драйвер."
        Solution    = "1. Запустите 'Перезапустить службу' в меню трея (выполняется автоматический сброс адаптера).`n2. Или запустите ProksiFi_Setup.exe поверх — установщик проведет полную автоочистку."
    },
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
        Description = "Локальный порт 7890 занят посторонней программой."
        Cause       = "Параллельно запущен сторонний прокси (Clash, Mihomo, V2RayN, Nekoray, Amnezia)."
        Solution    = "Закройте сторонний VPN/прокси-клиент и перезапустите ProksiFi."
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
        Description = "Не удается завершить шифрованное Reality-рукопожатие с сервером во Франкфурте."
        Cause       = "Часы Windows расходятся с мировым временем более чем на 60 секунд, либо антивирус перехватывает SSL."
        Solution    = "Откройте 'Параметры Windows' -> 'Дата и время' -> нажмите 'Синхронизировать'."
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
        Description = "Пакеты до сервера во Франкфурте теряются или блокируются провайдером."
        Cause       = "Кратковременные помехи провайдера или фильтрация ТСПУ/РКН."
        Solution    = "Обычно проходит в течение 1-2 минут. При необходимости нажмите 'Перезапустить службу'."
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
        Description = "Запросы к прокси сбрасываются, процесс core.exe не активен."
        Cause       = "Служба остановлена или упала при старте."
        Solution    = "Кликните правой кнопкой на значок ProksiFi в трее и выберите 'Включить обход'."
    },
    @{
        Id          = "DNS_RESOLUTION_FAILURE"
        Severity    = "WARNING"
        Title       = "Сбой разрешения доменных имен (DNS Error)"
        Patterns    = @(
            "dns: failed to resolve",
            "SERVFAIL",
            "NXDOMAIN",
            "dns query timed out"
        )
        Description = "Не удается преобразовать доменное имя в IP-адрес."
        Cause       = "Локальный DNS блокирует запросы."
        Solution    = "Перезапустите службу в трее для переподключения защищенного DoH."
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

function Test-ThirdPartyConflicts {
    $conflicts = @()

    # 1. Antigravity Unlockers & DNS patchers
    $agUnlockers = Get-Process -Name "ag_dns", "AG_Unlocker", "AG_2.26.0", "ag_proxy" -ErrorAction SilentlyContinue
    foreach ($p in $agUnlockers) {
        $conflicts += [PSCustomObject]@{
            Type     = "CRITICAL"
            Category = "Патчер Antigravity"
            Process  = "$($p.Name).exe (PID: $($p.Id))"
            Impact   = "Перехватывает переменную AG_LS_PROXY на свой порт, ломая встроенный туннель ProksiFi."
            Fix      = "Завершите процесс '$($p.Name)' в Диспетчере задач. ProksiFi обеспечивает полный нативный обход без сторонних патчеров."
        }
    }

    # 2. DPI bypass tools
    $dpiTools = Get-Process -Name "goodbyedpi", "zapret", "winws", "byedpi", "spoofdpi", "ciadpi" -ErrorAction SilentlyContinue
    foreach ($p in $dpiTools) {
        $conflicts += [PSCustomObject]@{
            Type     = "WARNING"
            Category = "DPI-обходчик (WinDivert)"
            Process  = "$($p.Name).exe (PID: $($p.Id))"
            Impact   = "Может фрагментировать TLS-пакеты Reality и замедлять соединение."
            Fix      = "Если наблюдаются сбои соединения с Франкфуртом — отключите $($p.Name)."
        }
    }

    # 3. Third-party Proxies & VPNs
    $vpnTools = Get-Process -Name "clash", "mihomo", "clash-verge", "clash-meta", "v2rayN", "v2ray", "nekoray", "nekobox", `
        "amnezia-vpn", "amnezia", "hiddify", "HiddifyCli", "hiddify-next", "shadowsocks", "sslocal", "ss-local", `
        "happd", "HappProxy", "happ", "outline-client", "OutlineService", `
        "lantern", "psiphon", "psiphon3", "xray", "sing-box", "hysteria" -ErrorAction SilentlyContinue
    foreach ($p in $vpnTools) {
        # Определяем читаемое имя известных программ
        $friendlyName = switch -Wildcard ($p.Name.ToLower()) {
            "happd"         { "Happ Proxy" }
            "happproxy"     { "Happ Proxy" }
            "happ"          { "Happ Proxy" }
            "hiddifycli"    { "Hiddify" }
            "hiddify*"      { "Hiddify" }
            "outline*"      { "Outline VPN" }
            "lantern"       { "Lantern VPN" }
            "psiphon*"      { "Psiphon VPN" }
            "clash*"        { "Clash" }
            "mihomo"        { "Mihomo/Clash.Meta" }
            "nekoray"       { "Nekoray" }
            "nekobox"       { "Nekobox" }
            "v2ray*"        { "v2rayN" }
            "amnezia*"      { "AmneziaVPN" }
            "shadowsocks"   { "Shadowsocks" }
            "sslocal"       { "Shadowsocks" }
            "xray"          { "Xray-core" }
            "sing-box"      { "sing-box" }
            "hysteria"      { "Hysteria" }
            default         { $p.Name }
        }
        $conflicts += [PSCustomObject]@{
            Type     = "CRITICAL"
            Category = "Сторонний VPN/Прокси ($friendlyName)"
            Process  = "$($p.Name).exe (PID: $($p.Id))"
            Impact   = "Занимает порт 7890 или системный прокси Windows — соединение ProksiFi обрывается (HTTP 000)."
            Fix      = "Закройте '$friendlyName' во избежание конфликта портов. ProksiFi обеспечивает полный обход самостоятельно."
        }
    }

    # 4. Check port 53129
    $port53129 = Get-NetTCPConnection -LocalPort 53129 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($port53129) {
        $conflicts += [PSCustomObject]@{
            Type     = "WARNING"
            Category = "Служебный порт ag_dns"
            Process  = "Порт 127.0.0.1:53129 (Владелец PID: $($port53129.OwningProcess))"
            Impact   = "Обнаружен активный порт стороннего DNS-патчера Antigravity."
            Fix      = "Рекомендуется отключить сторонний фикс."
        }
    }

    # 5. Check environment variable AG_LS_PROXY
    $userAgProxy = [System.Environment]::GetEnvironmentVariable("AG_LS_PROXY", "User")
    if ($userAgProxy -and $userAgProxy -ne "http://127.0.0.1:7890") {
        $conflicts += [PSCustomObject]@{
            Type     = "CRITICAL"
            Category = "Переменная AG_LS_PROXY"
            Process  = "AG_LS_PROXY = '$userAgProxy'"
            Impact   = "Antigravity направляет запросы на чужой прокси ($userAgProxy) вместо ProksiFi (127.0.0.1:7890)!"
            Fix      = "Запустите 'Быстрое автоисправление сети' в меню трея для восстановления адреса http://127.0.0.1:7890."
        }
    }

    return $conflicts
}

function Get-AntigravityProducts {
    $found = @()

    # 1. Antigravity IDE
    $ideCandidates = @(
        "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe",
        "C:\Program Files\Antigravity\Antigravity.exe",
        "C:\Program Files (x86)\Antigravity\Antigravity.exe"
    )
    $ideExe = $null
    foreach ($cand in $ideCandidates) {
        if (Test-Path $cand) { $ideExe = $cand; break }
    }
    $ideProcs = Get-Process -Name "Antigravity" -ErrorAction SilentlyContinue

    if ($ideExe -or $ideProcs) {
        $found += [PSCustomObject]@{
            Name        = "Antigravity IDE (IDE Разработчика)"
            Path        = if ($ideExe) { $ideExe } else { $ideProcs[0].Path }
            IsInstalled = ($ideExe -ne $null)
            IsRunning   = ($ideProcs -ne $null -and $ideProcs.Count -gt 0)
            Instances   = if ($ideProcs) { $ideProcs.Count } else { 0 }
            Type        = "IDE"
        }
    }

    # 2. Antigravity Language Server
    $lsCandidates = @(
        "$env:LOCALAPPDATA\Programs\antigravity\resources\bin\language_server.exe",
        "C:\Program Files\Antigravity\resources\bin\language_server.exe"
    )
    $lsExe = $null
    foreach ($cand in $lsCandidates) {
        if (Test-Path $cand) { $lsExe = $cand; break }
    }
    $lsProcs = Get-Process -Name "language_server" -ErrorAction SilentlyContinue

    if ($lsExe -or $lsProcs) {
        $lsConnectedToProxy = $false
        if ($lsProcs) {
            $conns = Get-NetTCPConnection -OwningProcess $lsProcs[0].Id -ErrorAction SilentlyContinue
            $lsConnectedToProxy = ($conns | Where-Object { $_.RemotePort -eq 7890 }) -ne $null
        }

        $found += [PSCustomObject]@{
            Name        = "Antigravity Language Server (Языковой агент ИИ)"
            Path        = if ($lsExe) { $lsExe } else { $lsProcs[0].Path }
            IsInstalled = ($lsExe -ne $null)
            IsRunning   = ($lsProcs -ne $null)
            Instances   = if ($lsProcs) { $lsProcs.Count } else { 0 }
            ProxyActive = $lsConnectedToProxy
            Type        = "LanguageServer"
        }
    }

    # 3. Antigravity CLI (agy)
    $cliCandidates = @(
        "$env:USERPROFILE\.gemini\bin\agy.exe",
        "$env:LOCALAPPDATA\agy\bin\agy.exe",
        "C:\Program Files\agy\agy.exe",
        "$env:LOCALAPPDATA\Programs\antigravity\resources\bin\agy.exe"
    )
    $cliExe = $null
    foreach ($cand in $cliCandidates) {
        if (Test-Path $cand) { $cliExe = $cand; break }
    }
    if (-not $cliExe) {
        $cliCmd = Get-Command agy -ErrorAction SilentlyContinue
        if ($cliCmd) { $cliCmdPath = $cliCmd.Source; if ($cliCmdPath -and (Test-Path $cliCmdPath)) { $cliExe = $cliCmdPath } }
    }
    $cliProcs = Get-Process -Name "agy" -ErrorAction SilentlyContinue

    if ($cliExe -or $cliProcs) {
        $ver = "Утилита доступна"
        if ($cliExe) {
            try { $ver = (& $cliExe --version 2>&1).Trim() } catch {}
        }
        $found += [PSCustomObject]@{
            Name        = "Antigravity CLI (Утилита agy)"
            Path        = $cliExe
            IsInstalled = ($cliExe -ne $null)
            IsRunning   = ($cliProcs -ne $null)
            Version     = $ver
            Type        = "CLI"
        }
    }

    # 4. Antigravity Plugins & Skills Root
    $geminiDir = "$env:USERPROFILE\.gemini\antigravity"
    if (Test-Path $geminiDir) {
        $skillsCount = 0
        $skillsDir = Join-Path $geminiDir "builtin\skills"
        if (Test-Path $skillsDir) {
            $skillsCount = (Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue).Count
        }
        $found += [PSCustomObject]@{
            Name        = "Antigravity Plugins & Skills (Модули и скиллы)"
            Path        = $geminiDir
            IsInstalled = $true
            IsRunning   = $true
            Details     = "Найдено $skillsCount встроенных навыков"
            Type        = "Skills"
        }
    }

    # 5. VS Code с расширениями Gemini / Antigravity
    $vscodeProcs = Get-Process -Name "Code" -ErrorAction SilentlyContinue
    $vscodeExtDir = "$env:USERPROFILE\.vscode\extensions"
    $geminiExts = @()
    if (Test-Path $vscodeExtDir) {
        $geminiExts = Get-ChildItem -Path $vscodeExtDir -Directory -Filter "*gemini*" -ErrorAction SilentlyContinue
    }
    if ($geminiExts.Count -gt 0 -or $vscodeProcs) {
        $found += [PSCustomObject]@{
            Name        = "VS Code (Расширения Gemini Assist)"
            Path        = if ($vscodeProcs) { $vscodeProcs[0].Path } else { "VS Code" }
            IsInstalled = ($geminiExts.Count -gt 0)
            IsRunning   = ($vscodeProcs -ne $null)
            Details     = if ($geminiExts.Count -gt 0) { "Установлено расширений: $($geminiExts.Count)" } else { "Активен" }
            Type        = "VSCode"
        }
    }

    return $found
}

function Test-AntigravityConnectivity {
    param([int]$TimeoutSec = 6)

    $endpoints = @(
        @{
            Name     = "Google Gemini (Веб-портал)"
            Url      = "https://gemini.google.com"
            Purpose  = "Веб-интерфейс Gemini и авторизация"
            Expected = @("200", "302")
        },
        @{
            Name     = "Antigravity Cloud Code Gateway"
            Url      = "https://daily-cloudcode-pa.googleapis.com"
            Purpose  = "Шлюз Language Server и Cloud Code в IDE"
            Expected = @("404", "200", "403")
        },
        @{
            Name     = "Antigravity Production Gateway"
            Url      = "https://cloudcode-pa.googleapis.com"
            Purpose  = "Продакшн шлюз Google Cloud Code"
            Expected = @("404", "200", "403")
        },
        @{
            Name     = "Google Generative AI / Gemini API"
            Url      = "https://generativelanguage.googleapis.com"
            Purpose  = "API моделей Gemini (Flash, Pro, Thinking) для кода"
            Expected = @("404", "200", "403")
        },
        @{
            Name     = "Google MakerSuite / Studio Backend"
            Url      = "https://alkalimakersuite-pa.clients6.google.com"
            Purpose  = "Бэкенд AI Studio и системных инструкций"
            Expected = @("302", "200", "404")
        },
        @{
            Name     = "Google AI Studio"
            Url      = "https://aistudio.google.com"
            Purpose  = "Портал разработчика Google AI Studio"
            Expected = @("302", "200")
        },
        @{
            Name     = "Google NotebookLM"
            Url      = "https://notebooklm.google.com"
            Purpose  = "AI ассистент Google для документов"
            Expected = @("301", "302", "200")
        },
        @{
            Name     = "Google Accounts / OAuth Sign-in"
            Url      = "https://accounts.google.com"
            Purpose  = "Авторизация и токены Google в Antigravity"
            Expected = @("302", "200")
        },
        @{
            Name     = "Google Play Services Config"
            Url      = "https://play.googleapis.com"
            Purpose  = "Обновление конфигураций и телеметрии"
            Expected = @("404", "200", "403")
        }
    )

    $results = @()
    foreach ($ep in $endpoints) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $code = & curl.exe -s -o NUL -w "%{http_code}" -m $TimeoutSec -x http://127.0.0.1:7890 $ep.Url
            $sw.Stop()
            $ms = $sw.ElapsedMilliseconds
            $isOk = $code -in $ep.Expected
            $results += [PSCustomObject]@{
                Name      = $ep.Name
                Url       = $ep.Url
                Purpose   = $ep.Purpose
                HttpCode  = $code
                LatencyMs = $ms
                IsOk      = $isOk
            }
        } catch {
            $sw.Stop()
            $results += [PSCustomObject]@{
                Name      = $ep.Name
                Url       = $ep.Url
                Purpose   = $ep.Purpose
                HttpCode  = "ERR"
                LatencyMs = $sw.ElapsedMilliseconds
                IsOk      = $false
            }
        }
    }
    return $results
}


function Send-ProksiFiLogsToServer {
    param(
        [switch]$Interactive,
        [string]$DiagnosticSummary = "",
        [string]$ServerEndpoint = "http://138.124.62.86:7979/api/upload-log"
    )

    Write-Host "`n══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "           ОТПРАВКА ЖУРНАЛА ЛОГОВ РАЗРАБОТЧИКУ НА СЕРВЕР               " -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    $profilePath = "$env:ProgramData\ProksiFi\device.json"
    if (-not (Test-Path $profilePath)) {
        $profilePath = "$env:ProgramData\AntigravityBypass\device.json"
    }

    $email = "unknown_client"
    $shortHwid = ""
    $hwid = ""
    $uuidStr = ""

    if (Test-Path $profilePath) {
        try {
            $prof = Get-Content -Path $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $email = if ($prof.Email) { $prof.Email } else { "client_$($prof.ShortHWID)" }
            $shortHwid = $prof.ShortHWID
            $hwid = $prof.HWID
            $uuidStr = $prof.UUID
        } catch { }
    }

    if (-not $shortHwid) {
        $rawHwid = "$env:COMPUTERNAME-$env:USERNAME"
        $shortHwid = [System.BitConverter]::ToString(([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rawHwid)))).Replace("-","").Substring(0,8).ToLower()
        $email = "client_$shortHwid"
    }

    Write-Host "  Идентификатор клиента: $email ($shortHwid)" -ForegroundColor Cyan
    Write-Host "  Компьютер:             $env:COMPUTERNAME" -ForegroundColor Gray

    if (-not $DiagnosticSummary) {
        Write-Host "  -> Сбор актуальных данных о состоянии системы..." -ForegroundColor Gray
        $svc = Get-Service -Name "ProksiFiService", "AntigravityBypassService" -ErrorAction SilentlyContinue | Select-Object -First 1
        $core = Get-Process -Name "core" -ErrorAction SilentlyContinue | Select-Object -First 1
        $port7890 = Get-NetTCPConnection -LocalPort 7890 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        $tun = Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Select-Object -First 1

        $DiagnosticSummary = @"
1. СИСТЕМА И СЛУЖБА:
  Служба: $svc ($($svc.Status))
  Ядро core.exe: $(if ($core) { "PID $($core.Id)" } else { "НЕ ЗАПУЩЕН" })
  Порт 7890: $(if ($port7890) { "Слушается" } else { "Закрыт" })
  Адаптер WinTun: $(if ($tun) { "$($tun.Name) ($($tun.Status))" } else { "Не активен" })
  AG_LS_PROXY: $([System.Environment]::GetEnvironmentVariable("AG_LS_PROXY", "User"))
"@
    }

    $dataDir = "$env:ProgramData\ProksiFi"
    $serviceLogTail = ""
    $errLogTail = ""
    $serviceLogPath = Join-Path $dataDir "logs\service.log"
    $errLogPath = Join-Path $dataDir "logs\service.err.log"

    if (Test-Path $serviceLogPath) {
        try {
            $serviceLogTail = (Get-Content -Path $serviceLogPath -Tail 100 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n"
        } catch { }
    }
    if (Test-Path $errLogPath) {
        try {
            $errLogTail = (Get-Content -Path $errLogPath -Tail 40 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n"
        } catch { }
    }

    $agLogTail = ""
    $agLogs = @(
        "$env:APPDATA\Antigravity\logs\language_server.log",
        "$env:APPDATA\Antigravity\logs\main.log",
        "$env:USERPROFILE\.gemini\antigravity\logs\vs_ls.log",
        "$env:USERPROFILE\.gemini\antigravity\cli.log"
    )
    foreach ($alf in $agLogs) {
        if (Test-Path $alf) {
            $fName = Split-Path $alf -Leaf
            $agLogTail += "`n--- [$fName] ---`n"
            $agLogTail += (Get-Content -Path $alf -Tail 35 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n"
        }
    }

    $userNotes = ""
    if ($Interactive) {
        Write-Host ""
        try {
            $userNotes = Read-Host "Кратко опишите проблему (или нажмите Enter чтобы отправить без комментария)"
        } catch { }
    }

    $payloadObj = [PSCustomObject]@{
        email             = $email
        short_hwid        = $shortHwid
        hwid              = $hwid
        uuid              = $uuidStr
        computer_name     = $env:COMPUTERNAME
        os_caption        = ((Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption)
        diagnostic_report = $DiagnosticSummary
        service_log       = $serviceLogTail
        service_err_log   = $errLogTail
        antigravity_logs  = $agLogTail
        user_notes        = $userNotes
    }

    $tempJson = Join-Path $env:TEMP "proksifi_report_$([guid]::NewGuid().ToString('N')).json"
    $payloadJson = $payloadObj | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempJson, $payloadJson, $utf8NoBom)

    Write-Host "  -> Отправка пакета на сервер разработчика..." -ForegroundColor Cyan

    try {
        $resp = (& curl.exe --noproxy "*" -s -m 15 -X POST -H "Content-Type: application/json; charset=utf-8" --data-binary "@$tempJson" $ServerEndpoint 2>&1) -join "`n"
        Remove-Item -LiteralPath $tempJson -Force -ErrorAction SilentlyContinue

        if ($resp -match '"success":\s*true' -or $resp -match 'Отчет успешно') {
            Write-Host "`n  [OK] Логи успешно отправлены на сервер разработчика!" -ForegroundColor Green
            Write-Host "       Ваша личная папка на сервере: $email" -ForegroundColor Green
            Write-Host "       Разработчик сможет изучить логи и помочь с решением." -ForegroundColor Cyan
            return $true
        } elseif ([string]::IsNullOrWhiteSpace($resp)) {
            Write-Host "  [!] Сервер не ответил (проверьте интернет или закройте сторонние VPN/прокси, блокирующие сеть)." -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "  [!] Ответ сервера: $resp" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  [ERR] Не удалось связаться с сервером: $_" -ForegroundColor Red
        return $false
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
    Write-Host "`n[1/6] ПРОВЕРКА СОСТОЯНИЯ СИСТЕМЫ И СЛУЖБЫ:" -ForegroundColor Yellow

    $serviceName = "ProksiFiService"
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $svc) {
        $svc = Get-Service -Name "AntigravityBypassService" -ErrorAction SilentlyContinue
        if ($svc) { $serviceName = "AntigravityBypassService" }
    }

    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "  [OK] Служба Windows:      $serviceName (Работает)" -ForegroundColor Green
    } elseif ($svc) {
        Write-Host "  [ERR] Служба Windows:     $serviceName ($($svc.Status))" -ForegroundColor Red
    } else {
        Write-Host "  [ERR] Служба Windows:     НЕ УСТАНОВЛЕНА" -ForegroundColor Red
    }

    # Core process check
    $coreProc = Get-Process -Name "core" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($coreProc) {
        $ramMb = [Math]::Round($coreProc.WorkingSet64 / 1MB, 1)
        Write-Host "  [OK] Процесс ядра:        core.exe (PID: $($coreProc.Id), Память: $ramMb МБ)" -ForegroundColor Green
    } else {
        Write-Host "  [ERR] Процесс ядра:       core.exe НЕ ЗАПУЩЕН" -ForegroundColor Red
    }

    # Port 7890 check
    $portConn = Get-NetTCPConnection -LocalPort 7890 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portConn) {
        if ($coreProc -and $portConn.OwningProcess -eq $coreProc.Id) {
            Write-Host "  [OK] Порт 127.0.0.1:7890: Открыт и слушается процессом core.exe" -ForegroundColor Green
        } else {
            Write-Host "  [ERR] Порт 127.0.0.1:7890: ЗАНЯТ ЧУЖИМ ПРОЦЕССОМ (PID: $($portConn.OwningProcess))!" -ForegroundColor Red
        }
    } else {
        if ($svc -and $svc.Status -eq "Running") {
            Write-Host "  [ERR] Порт 127.0.0.1:7890: Не слушается (ядро не открыло порт)" -ForegroundColor Red
        } else {
            Write-Host "  [INFO] Порт 127.0.0.1:7890: Закрыт (служба остановлена)" -ForegroundColor Gray
        }
    }

    # System Proxy check
    $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($proxySettings -and $proxySettings.ProxyEnable -eq 1) {
        Write-Host "  [OK] Системный прокси:    ВКЛЮЧЕН ($($proxySettings.ProxyServer))" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Системный прокси:    ВЫКЛЮЧЕН (Прямой доступ)" -ForegroundColor Gray
    }

    # WinTun adapter check
    $tunAdapter = Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tunAdapter -and $tunAdapter.Status -eq "Up") {
        Write-Host "  [OK] Туннельный адаптер:  $($tunAdapter.Name) (Статус: Up)" -ForegroundColor Green
    } elseif ($tunAdapter) {
        Write-Host "  [WARN] Туннельный адаптер: $($tunAdapter.Name) (Статус: $($tunAdapter.Status))" -ForegroundColor Yellow
    } else {
        Write-Host "  [INFO] Туннельный адаптер: ProksiFiTUN не создан (режим прокси)" -ForegroundColor Gray
    }

    # Antigravity IDE Environment Variable Check
    $userAgProxy = [System.Environment]::GetEnvironmentVariable("AG_LS_PROXY", "User")
    if ($userAgProxy -eq "http://127.0.0.1:7890") {
        Write-Host "  [OK] Antigravity Proxy:   AG_LS_PROXY = http://127.0.0.1:7890" -ForegroundColor Green
    } elseif ($userAgProxy) {
        Write-Host "  [WARN] Antigravity Proxy:  AG_LS_PROXY = $userAgProxy (Ожидается: http://127.0.0.1:7890)" -ForegroundColor Yellow
    } else {
        Write-Host "  [INFO] Antigravity Proxy:  AG_LS_PROXY не задан (используется системный прокси)" -ForegroundColor Gray
    }

    # Windows Time Sync Check
    $timeCheck = Test-TimeSync
    if ($timeCheck.Success) {
        if ($timeCheck.IsCritical) {
            Write-Host "  [ERR] Время Windows:       РАССИНХРОНИЗАЦИЯ ($($timeCheck.OffsetSeconds) сек)! Reality handshake может сбоить!" -ForegroundColor Red
        } else {
            Write-Host "  [OK] Время Windows:       Точное (смещение $($timeCheck.OffsetSeconds) сек)" -ForegroundColor Green
        }
    } else {
        Write-Host "  [INFO] Время Windows:       Проверка NTP пропущена" -ForegroundColor Gray
    }

    # -------------------------------------------------------------------------
    # 2. SMART CHECK FOR THIRD-PARTY CONFLICTS (DPI / PROXY / DNS PATCHERS)
    # -------------------------------------------------------------------------
    Write-Host "`n[2/6] СКАНИРОВАНИЕ НА СТОРОННИЕ ПАТЧЕРЫ, VPN И ДНС-ПРОКСИ:" -ForegroundColor Yellow
    $conflicts = Test-ThirdPartyConflicts
    if ($conflicts.Count -eq 0) {
        Write-Host "  [OK] Сторонних конфликтующих патчеров и прокси не обнаружено." -ForegroundColor Green
    } else {
        Write-Host "  [!] ВНИМАНИЕ: Обнаружено потенциальных конфликтов: $($conflicts.Count)" -ForegroundColor Yellow
        foreach ($c in $conflicts) {
            $badgeColor = if ($c.Type -eq "CRITICAL") { "Red" } else { "Yellow" }
            Write-Host "  ┌──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
            Write-Host "  │ [$($c.Category)] $($c.Process)" -ForegroundColor $badgeColor
            Write-Host "  │ Влияние:  $($c.Impact)" -ForegroundColor White
            Write-Host "  │ Решение:  $($c.Fix)" -ForegroundColor Cyan
            Write-Host "  └──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
        }
    }

    # -------------------------------------------------------------------------
    # 3. ANTIGRAVITY & GEMINI PRODUCTS DISCOVERY
    # -------------------------------------------------------------------------
    Write-Host "`n[3/6] ОБНАРУЖЕНИЕ ПРОДУКТОВ ANTIGRAVITY & GOOGLE GEMINI НА ПК:" -ForegroundColor Yellow
    $products = Get-AntigravityProducts
    if ($products.Count -eq 0) {
        Write-Host "  [INFO] На данном ПК не найдено установленных продуктов Antigravity." -ForegroundColor Gray
    } else {
        Write-Host "  Найдено связанных продуктов: $($products.Count)" -ForegroundColor Cyan
        foreach ($p in $products) {
            $statusLabel = if ($p.IsRunning) { "🟢 Активен (Запущен)" } elseif ($p.IsInstalled) { "⚪ Установлен (Остановлен)" } else { "🔴 Не установлен" }
            Write-Host "  • $($p.Name)" -ForegroundColor White
            Write-Host "    Статус:    $statusLabel" -ForegroundColor $(if ($p.IsRunning) { "Green" } else { "Yellow" })
            if ($p.Path) { Write-Host "    Путь:      $($p.Path)" -ForegroundColor Gray }
            if ($p.Version) { Write-Host "    Версия:    $($p.Version)" -ForegroundColor Gray }
            if ($p.Details) { Write-Host "    Инфо:      $($p.Details)" -ForegroundColor Gray }
            if ($p.ProxyActive) { Write-Host "    Прокси:    ✔ Направляет трафик в 127.0.0.1:7890" -ForegroundColor Green }
        }
    }

    # -------------------------------------------------------------------------
    # 4. TARGET CONNECTIVITY TEST FOR ANTIGRAVITY & GEMINI API GATEWAYS
    # -------------------------------------------------------------------------
    Write-Host "`n[4/6] ТЕСТИРОВАНИЕ КАНАЛОВ СВЯЗИ ПРОДУКТОВ ANTIGRAVITY & GEMINI API:" -ForegroundColor Yellow
    $agResults = Test-AntigravityConnectivity
    foreach ($r in $agResults) {
        $statusBadge = if ($r.IsOk) { "[OK]" } else { "[СБОЙ]" }
        $color = if ($r.IsOk) { "Green" } else { "Red" }
        Write-Host "  $statusBadge " -NoNewline -ForegroundColor $color
        Write-Host "$($r.Name.PadRight(35)) " -NoNewline -ForegroundColor White
        Write-Host "-> HTTP $($r.HttpCode.PadRight(4)) " -NoNewline -ForegroundColor $color
        Write-Host "($($r.LatencyMs) мс)" -ForegroundColor Cyan
    }

    # -------------------------------------------------------------------------
    # 5. LOG SCANNING & AUTOMATED ERROR RECOGNITION (INC. MODEL QUOTAS)
    # -------------------------------------------------------------------------
    Write-Host "`n[5/6] АНАЛИЗ ЖУРНАЛОВ И РАСПОЗНАВАНИЕ ОШИБОК (ВКЛ. КВОТЫ ИИ):" -ForegroundColor Yellow

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
                            Signature  = $sig
                            Count      = 1
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
        Write-Host "  [OK] В журналах работы критических ошибок сети не обнаружено!" -ForegroundColor Green
        Write-Host "       (Проанализировано строк логов: $($allLogLines.Count))" -ForegroundColor Gray
    } else {
        Write-Host "  [!] Обнаружено распознанных событий в логах: $($detectedErrors.Count)`n" -ForegroundColor Yellow

        foreach ($key in $detectedErrors.Keys) {
            $err = $detectedErrors[$key]
            $sig = $err.Signature

            $badgeColor = if ($sig.Severity -eq "CRITICAL") { "Red" } else { "Yellow" }
            Write-Host "  ┌──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
            Write-Host "  │ [$($sig.Severity)] $($sig.Title) (Зафиксировано: $($err.Count) раз)" -ForegroundColor $badgeColor
            Write-Host "  ├──────────────────────────────────────────────────────────────────" -ForegroundColor $badgeColor
            Write-Host "  │ Что произошло: $($sig.Description)" -ForegroundColor White
            Write-Host "  │ Первопричина:   $($sig.Cause)" -ForegroundColor Cyan
            Write-Host "  │ Что делать:     $($sig.Solution)" -ForegroundColor Green
            Write-Host "  │ Пример из лога: $($err.SampleLine)" -ForegroundColor DarkGray
            Write-Host "  └──────────────────────────────────────────────────────────────────`n" -ForegroundColor $badgeColor
        }
    }

    # -------------------------------------------------------------------------
    # 6. LIVE ROUTING FOR OTHER SERVICES (CHATGPT, TELEGRAM, RUSSIAN DIRECT)
    # -------------------------------------------------------------------------
    Write-Host "[6/6] ЭКСПРЕСС-ПРОВЕРКА ДРУГИХ СЕРВИСОВ ОБХОДА И МАРШРУТИЗАЦИИ:" -ForegroundColor Yellow

    # ChatGPT Web
    $resChatGpt = "000"
    Write-Host "  1. ChatGPT (https://chatgpt.com)..." -NoNewline
    try {
        $resChatGpt = & curl.exe -s -o NUL -w "%{http_code}" -m 6 -x http://127.0.0.1:7890 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0.0.0" https://chatgpt.com
        if ($resChatGpt -eq "200" -or $resChatGpt -eq "307" -or $resChatGpt -eq "403") {
            Write-Host " [OK] Доступен (HTTP $resChatGpt)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $resChatGpt]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # SoundCloud
    $resSoundCloud = "000"
    Write-Host "  2. SoundCloud (https://soundcloud.com)..." -NoNewline
    try {
        $resSoundCloud = & curl.exe -s -o NUL -w "%{http_code}" -m 6 -x http://127.0.0.1:7890 https://soundcloud.com
        if ($resSoundCloud -eq "200" -or $resSoundCloud -eq "301" -or $resSoundCloud -eq "302") {
            Write-Host " [OK] (HTTP $resSoundCloud)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $resSoundCloud]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # Telegram
    $resTelegram = "000"
    Write-Host "  3. Telegram (https://t.me)..." -NoNewline
    try {
        $resTelegram = & curl.exe -s -o NUL -w "%{http_code}" -m 6 -x http://127.0.0.1:7890 https://t.me
        if ($resTelegram -eq "200" -or $resTelegram -eq "302") {
            Write-Host " [OK] (HTTP $resTelegram)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $resTelegram]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # Yandex Direct
    $resYa = "000"
    Write-Host "  4. Прямой российский трафик (ya.ru)..." -NoNewline
    try {
        $resYa = & curl.exe -s -o NUL -w "%{http_code}" -m 5 https://ya.ru
        if ($resYa -eq "200" -or $resYa -eq "302") {
            Write-Host " [OK] (Direct без прокси)" -ForegroundColor Green
        } else {
            Write-Host " [HTTP $resYa]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
    }

    # IP & Country
    $ipObj = $null
    Write-Host "  5. Проверка геопозиции (ipinfo.io)..." -NoNewline
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

    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host "     ДИАГНОСТИКА ЗАВЕРШЕНА                                             " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    # -------------------------------------------------------------------------
    # 7. ФОРМИРОВАНИЕ ПОЛНОГО ОТЧЕТА И ИНТЕРАКТИВНЫЙ ЭКСПОРТ
    # -------------------------------------------------------------------------
    $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = "$env:USERPROFILE\Desktop"
    }

    # Формируем полный отчет заранее, чтобы он всегда отправлялся на сервер полностью
    $reportContent = @"
======================================================================
     PROKSIFI v2.0 — ПОЛНЫЙ ОТЧЕТ ДИАГНОСТИКИ И АНАЛИЗА СИСТЕМЫ
======================================================================
Дата и время проверки: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Имя компьютера:        $env:COMPUTERNAME
Пользователь:          $env:USERNAME
Операционная система:  $((Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption)

----------------------------------------------------------------------
1. СОСТОЯНИЕ СЛУЖБЫ И СЕТЕВЫХ КОМПОНЕНТОВ
----------------------------------------------------------------------
  Служба Windows:      $serviceName ($(if ($svc) { $svc.Status } else { "НЕ УСТАНОВЛЕНА" }))
  Процесс core.exe:    $(if ($coreProc) { "PID $($coreProc.Id), RAM: $ramMb МБ" } else { "НЕ ЗАПУЩЕН" })
  Порт 127.0.0.1:7890: $(if ($portConn) { "Слушается (PID $($portConn.OwningProcess))" } else { "ЗАКРЫТ" })
  Системный прокси:    $(if ($proxySettings -and $proxySettings.ProxyEnable -eq 1) { "ВКЛ ($($proxySettings.ProxyServer))" } else { "ВЫКЛ" })
  Адаптер WinTun:      $(if ($tunAdapter) { "$($tunAdapter.Name) (Статус: $($tunAdapter.Status))" } else { "Не активен" })
  AG_LS_PROXY:         $(if ($userAgProxy) { $userAgProxy } else { "Не задан" })
  Смещение времени:    $(if ($timeCheck.Success) { "$($timeCheck.OffsetSeconds) сек" } else { "Не проверено" })

----------------------------------------------------------------------
2. СКАНИРОВАНИЕ НА СТОРОННИЕ ПАТЧЕРЫ И КОНФЛИКТЫ
----------------------------------------------------------------------
$(if ($conflicts.Count -eq 0) { "  Конфликтующих патчеров (DPI, DNS, сторонних VPN) не обнаружено." } else {
    ($conflicts | ForEach-Object { "  [$($_.Type)] $($_.Category): $($_.Process)`r`n    Влияние: $($_.Impact)`r`n    Решение: $($_.Fix)" }) -join "`r`n`r`n"
})

----------------------------------------------------------------------
3. ПРОДУКТЫ ANTIGRAVITY & GEMINI НА ПК
----------------------------------------------------------------------
$(if ($products.Count -eq 0) { "  Продукты не обнаружены в стандартных путях." } else {
    ($products | ForEach-Object { "  • $($_.Name) | Запущен: $($_.IsRunning) | Путь: $($_.Path) $(if ($_.Details) { "($($_.Details))" })" }) -join "`r`n"
})

----------------------------------------------------------------------
4. ТЕСТИРОВАНИЕ ШЛЮЗОВ СВЯЗИ GEMINI & ANTIGRAVITY API
----------------------------------------------------------------------
$(($agResults | ForEach-Object { "  $(if ($_.IsOk) { '[OK]' } else { '[FAIL]' }) $($_.Name.PadRight(35)) -> HTTP $($_.HttpCode.PadRight(4)) ($($_.LatencyMs) мс)" }) -join "`r`n")

----------------------------------------------------------------------
5. РАСПОЗНАННЫЕ ОШИБКИ И СБОИ В ЖУРНАЛАХ (ВКЛЮЧАЯ КВОТЫ ИИ)
----------------------------------------------------------------------
$(if ($detectedErrors.Count -eq 0) { "  Критических сетевых сбоев или ошибок квот в журналах не найдено." } else {
    ($detectedErrors.Keys | ForEach-Object {
        $e = $detectedErrors[$_]
        "  • [$($e.Signature.Severity)] $($e.Signature.Title) (Повторов: $($e.Count))`r`n    Что произошло: $($e.Signature.Description)`r`n    Первопричина:   $($e.Signature.Cause)`r`n    Что делать:     $($e.Signature.Solution)`r`n    Пример строки:  $($e.SampleLine)"
    }) -join "`r`n`r`n"
})

----------------------------------------------------------------------
6. ДОСТУПНОСТЬ ДРУГИХ СЕРВИСОВ ОБХОДА
----------------------------------------------------------------------
  ChatGPT:    $(if ($resChatGpt -eq "200" -or $resChatGpt -eq "307" -or $resChatGpt -eq "403") { "OK (HTTP $resChatGpt)" } else { "HTTP $resChatGpt" })
  SoundCloud: $(if ($resSoundCloud -eq "200" -or $resSoundCloud -eq "301" -or $resSoundCloud -eq "302") { "OK (HTTP $resSoundCloud)" } else { "HTTP $resSoundCloud" })
  Telegram:   $(if ($resTelegram -eq "200" -or $resTelegram -eq "302") { "OK (HTTP $resTelegram)" } else { "HTTP $resTelegram" })
  Россия:     $(if ($resYa -eq "200" -or $resYa -eq "302") { "Прямой доступ OK (HTTP $resYa)" } else { "HTTP $resYa" })
  Геопозиция: $(if ($ipObj -and $ipObj.ip) { "$($ipObj.ip), $($ipObj.city) ($($ipObj.country))" } else { "Не определено" })
======================================================================
"@

    $createdFolder = $null

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                СОХРАНЕНИЕ ОТЧЕТОВ И ЖУРНАЛОВ ЛОГОВ                   " -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Запрос 1: Сохранение отчета диагностики и логов ProksiFi
    $saveProksiAns = Read-Host "Сохранить журнал логов на рабочий стол? (д/н или y/n)"
    if ($saveProksiAns -match '^(д|да|y|yes|d)$' -or $saveProksiAns -match '^[дyYdD]') {
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $targetDir = Join-Path $desktopPath "ProksiFi_Logs_$timestamp"
        $createdFolder = $targetDir

        try {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Write-Host "  -> Создана папка: $targetDir" -ForegroundColor Cyan

            # 1. Сохранение подробного текстового отчета
            $reportPath = Join-Path $targetDir "Diagnostic_Report.txt"
            Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8

            # 2. Копирование файлов логов ProksiFi
            $copiedCount = 0
            $proksiLogs = @(
                (Join-Path $LogDir "service.log"),
                (Join-Path $LogDir "service.err.log"),
                (Join-Path $LogDir "service.wrapper.log"),
                "$env:ProgramData\ProksiFi\install.log",
                "$env:ProgramData\AntigravityBypass\install.log",
                "$ScriptDir\install.log"
            )
            foreach ($lf in $proksiLogs) {
                if ($lf -and (Test-Path $lf)) {
                    Copy-Item -Path $lf -Destination $targetDir -Force -ErrorAction SilentlyContinue
                    $copiedCount++
                }
            }
            Write-Host "  [OK] Полный отчет и логи ProksiFi ($copiedCount файлов) сохранены:" -ForegroundColor Green
            Write-Host "       $targetDir" -ForegroundColor Green
        } catch {
            Write-Host "  [ERR] Ошибка при сохранении отчета: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [ПРОПУЩЕНО] Сохранение логов ProksiFi отменено пользователем." -ForegroundColor Gray
    }

    # Запрос 2: Копирование логов продуктов Antigravity
    Write-Host ""
    $saveAgAns = Read-Host "Скопировать журнал логов продуктов Antigravity на рабочий стол? (д/н или y/n)"
    if ($saveAgAns -match '^(д|да|y|yes|d)$' -or $saveAgAns -match '^[дyYdD]') {
        $agTargetDir = if ($createdFolder) {
            Join-Path $createdFolder "Antigravity_Logs"
        } else {
            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            Join-Path $desktopPath "Antigravity_Logs_$timestamp"
        }

        try {
            New-Item -ItemType Directory -Path $agTargetDir -Force | Out-Null
            Write-Host "  -> Поиск логов Antigravity в системе..." -ForegroundColor Cyan

            $agCopied = 0

            # 1. %APPDATA%\Antigravity\logs\*.log (language_server.log, main.log, etc.)
            $ideLogsDir = "$env:APPDATA\Antigravity\logs"
            if (Test-Path $ideLogsDir) {
                Get-ChildItem -Path $ideLogsDir -Filter "*.log" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $dest = Join-Path $agTargetDir "ide_$($_.Name)"
                    Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    Write-Host "     • $($_.Name) -> ide_$($_.Name)" -ForegroundColor Gray
                    $agCopied++
                }
            }

            # 2. %USERPROFILE%\.gemini\antigravity\logs\*.log (vs_ls.log, etc.)
            $geminiLsLogsDir = "$env:USERPROFILE\.gemini\antigravity\logs"
            if (Test-Path $geminiLsLogsDir) {
                Get-ChildItem -Path $geminiLsLogsDir -Filter "*.log" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $dest = Join-Path $agTargetDir "gemini_ls_$($_.Name)"
                    Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    Write-Host "     • $($_.Name) -> gemini_ls_$($_.Name)" -ForegroundColor Gray
                    $agCopied++
                }
            }

            # 3. %USERPROFILE%\.gemini\antigravity\cli.log
            $cliLog = "$env:USERPROFILE\.gemini\antigravity\cli.log"
            if (Test-Path $cliLog) {
                $dest = Join-Path $agTargetDir "gemini_cli.log"
                Copy-Item -Path $cliLog -Destination $dest -Force -ErrorAction SilentlyContinue
                Write-Host "     • cli.log -> gemini_cli.log" -ForegroundColor Gray
                $agCopied++
            }

            # 4. %USERPROFILE%\.gemini\antigravity\log\cli-*.log (latest 10 CLI logs)
            $cliSessionsDir = "$env:USERPROFILE\.gemini\antigravity\log"
            if (Test-Path $cliSessionsDir) {
                Get-ChildItem -Path $cliSessionsDir -Filter "cli-*.log" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 10 | ForEach-Object {
                        $dest = Join-Path $agTargetDir $_.Name
                        Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                        Write-Host "     • $($_.Name)" -ForegroundColor Gray
                        $agCopied++
                    }
            }

            # 5. %LOCALAPPDATA%\Programs\antigravity\*.log
            $localAgDir = "$env:LOCALAPPDATA\Programs\antigravity"
            if (Test-Path $localAgDir) {
                Get-ChildItem -Path $localAgDir -Filter "*.log" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $dest = Join-Path $agTargetDir "app_$($_.Name)"
                    Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                    Write-Host "     • $($_.Name) -> app_$($_.Name)" -ForegroundColor Gray
                    $agCopied++
                }
            }

            if ($agCopied -gt 0) {
                Write-Host "  [OK] Скопировано файлов логов Antigravity: $agCopied" -ForegroundColor Green
                Write-Host "       Папка: $agTargetDir" -ForegroundColor Green
            } else {
                Write-Host "  [INFO] Журналов логов Antigravity не обнаружено." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [ERR] Ошибка при копировании логов Antigravity: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [ПРОПУЩЕНО] Копирование логов Antigravity отменено пользователем." -ForegroundColor Gray
    }

    # Запрос 3: Отправка отчета разработчику на сервер
    Write-Host ""
    $sendDevAns = ""
    try {
        $sendDevAns = Read-Host "Отправить отчет и логи разработчику на сервер? (д/н или y/n)"
    } catch { }

    if ($sendDevAns -match '^[yYдДdD]' -or $sendDevAns -match '^(да|yes|da)$') {
        $null = Send-ProksiFiLogsToServer -DiagnosticSummary $reportContent
    } else {
        Write-Host "  [ПРОПУЩЕНО] Отправка логов разработчику отменена пользователем." -ForegroundColor Gray
    }

}

# Run diagnostics if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ProksiFiDiagnostics
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "         DIAGNOSTICS AND HEALTH AUDIT COMPLETED                       " -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    try {
        Write-Host "Press Enter to exit / Нажмите Enter для продолжения..." -ForegroundColor Yellow
        $null = Read-Host
    } catch { }
}
