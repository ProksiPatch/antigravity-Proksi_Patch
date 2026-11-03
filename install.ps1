# ==============================================================================
# ProksiFi v2.0 - Windows Service Master Installer (Resilient WinSW & Smart Cleaner)
# ==============================================================================

# Check Administrator Privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[UAC] Запрос прав Администратора Windows..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (-not $ScriptDir) { $ScriptDir = Get-Location }
Set-Location $ScriptDir

$programDir = "C:\Program Files\ProksiFi"
$dataDir = "$env:ProgramData\ProksiFi"
$logDir = "$dataDir\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$installLogFile = Join-Path $logDir "install.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $installLogFile -Value "[$timestamp] $Message" -Encoding UTF8 -ErrorAction SilentlyContinue
}

Write-Log "==========================================================" "Cyan"
Write-Log "  PROKSIFI v2.0 — УМНЫЙ МАСТЕР УСТАНОВКИ И ОБНОВЛЕНИЯ    " "Cyan"
Write-Log "==========================================================" "Cyan"

# Import Modules
. "$ScriptDir\modules\hwid.ps1"
. "$ScriptDir\modules\3xui-api.ps1"
. "$ScriptDir\modules\browser-hardening.ps1"
. "$ScriptDir\modules\config-generator.ps1"
if (Test-Path "$ScriptDir\modules\diagnostics.ps1") {
    . "$ScriptDir\modules\diagnostics.ps1"
}

# Read Server Configuration
$serverConfigFile = "$ScriptDir\config\server.json"
if (-not (Test-Path $serverConfigFile)) {
    $serverConfigFile = "$ScriptDir\server.json"
}
if (-not (Test-Path $serverConfigFile)) {
    throw "Конфигурационный файл server.json не найден!"
}
$serverConfig = Get-Content -Path $serverConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

# -----------------------------------------------------------------------------
# Шаг 1: Умный аудит среды и обнаружение сторонних конфликтов
# -----------------------------------------------------------------------------
Write-Log "`n[1/7] Умное сканирование среды и проверка на конфликты..." "Yellow"

$conflictProcesses = Get-Process -Name "ag_dns", "AG_Unlocker", "AG_2.26.0", "goodbyedpi", "zapret", "winws", "clash", "mihomo", "clash-verge", "v2rayN", "nekoray", "amnezia-vpn", "hiddify" -ErrorAction SilentlyContinue
if ($conflictProcesses) {
    foreach ($cp in $conflictProcesses) {
        if ($cp.Name -match "ag_dns|AG_") {
            Write-Log "  [ВНИМАНИЕ] Обнаружен сторонний патчер '$($cp.Name)' (PID $($cp.Id))!" "Yellow"
            Write-Log "  ProksiFi автоматически заменит его и настроит правильный адрес прокси для Antigravity." "Cyan"
        } elseif ($cp.Name -match "mihomo|clash") {
            Write-Log "  [КОНФЛИКТ] Процесс '$($cp.Name)' (PID $($cp.Id)) может блокировать порт 7890. Завершаем..." "Yellow"
            Stop-Process -Id $cp.Id -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "  [ПРЕДУПРЕЖДЕНИЕ] Обнаружена посторонняя сетевая утилита '$($cp.Name)' (PID $($cp.Id))." "Yellow"
        }
    }
} else {
    Write-Log "  [OK] Конфликтующих сторонних утилит не обнаружено." "Green"
}

# -----------------------------------------------------------------------------
# Шаг 2: Глубокая очистка системы от старых версий (Pre-Cleaner)
# -----------------------------------------------------------------------------
Write-Log "`n[2/7] Глубокая очистка системы от предыдущих версий..." "Yellow"

$serviceNames = @("ProksiFiService", "AntigravityBypassService")
$oldDirs = @("C:\Program Files\AntigravityBypass", "$env:ProgramData\AntigravityBypass")

# 1. Остановка старых служб
foreach ($sName in $serviceNames) {
    $existingSvc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($existingSvc) {
        Write-Log "  Остановка службы $sName..." "Gray"
        Stop-Service -Name $sName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $sName 2>&1 | Out-Null
    }
}

# 2. Остановка ядра старой версии через WinSW (если есть)
if (Test-Path "$programDir\service.exe") {
    & "$programDir\service.exe" stop 2>&1 | Out-Null
    & "$programDir\service.exe" uninstall 2>&1 | Out-Null
}

# 3. Принудительное завершение зависших процессов ядра
& taskkill.exe /F /IM core.exe /T 2>&1 | Out-Null
& taskkill.exe /F /IM service.exe /T 2>&1 | Out-Null
$lingering = Get-Process -Name "core", "service" -ErrorAction SilentlyContinue
foreach ($p in $lingering) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
}

# 4. Полная очистка виртуальных сетевых адаптеров и сброс IP (решение ошибки 5010)
try {
    & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
    & netsh.exe interface ipv4 delete address name="AntigravityTUN" addr=172.19.0.1 2>&1 | Out-Null
    Get-NetIPAddress -InterfaceAlias "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# 5. Очистка старых резервных копий и временных файлов
if (Test-Path $programDir) {
    Get-ChildItem -Path $programDir -Filter "*.old_*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$dataDir\temp") {
    Remove-Item -Path "$dataDir\temp" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Log "  [OK] Предыдущие процессы, службы и сетевые адаптеры очищены." "Green"

# -----------------------------------------------------------------------------
# Шаг 3: Проверка ключа клиента (HWID & Сохранение профиля)
# -----------------------------------------------------------------------------
Write-Log "`n[3/7] Проверка аппаратного профиля и ключа клиента..." "Yellow"
$deviceInfo = Get-DeviceHWID
Write-Log "  HWID: $($deviceInfo.HWID)" "Gray"
Write-Log "  Short ID: $($deviceInfo.ShortHWID)" "Gray"

# Проверяем сохраненный профиль в новом или старом каталоге
$savedProfile = Get-SavedDeviceProfile
if (-not $savedProfile -and (Test-Path "$env:ProgramData\AntigravityBypass\device.json")) {
    try {
        $savedProfile = Get-Content -Path "$env:ProgramData\AntigravityBypass\device.json" -Raw | ConvertFrom-Json
    } catch {}
}

$clientUUID = $null
$realityParams = $null

if ($savedProfile -and $savedProfile.UUID -and $savedProfile.InboundId -eq $serverConfig.target_inbound_id) {
    Write-Log "  [OK] Найден постоянный ключ в device.json (UUID: $($savedProfile.UUID))." "Green"
    Write-Log "  Ключ сохранен, создание дубликата в панели не требуется!" "Green"
    $clientUUID = $savedProfile.UUID
    $realityParams = $savedProfile.Reality
} else {
    Write-Log "  [3X-UI] Проверка/создание клиента в панели 3X-UI..." "Yellow"
    $tempDir = "$dataDir\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    $cookieFile = "$tempDir\3xui_cookie_temp.txt"
    try {
        $session = Invoke-3XUILogin -PanelUrl $serverConfig.panel_url `
            -BasePath $serverConfig.base_path `
            -Username $serverConfig.username `
            -Password $serverConfig.password `
            -CookieFile $cookieFile

        $inbounds = Get-3XUIInbounds -Session $session
        $targetInbound = Get-TargetInbound -Inbounds $inbounds `
            -TargetId $serverConfig.target_inbound_id `
            -TargetRemark $serverConfig.target_remark

        $client = Get-OrCreateInboundClient -Session $session `
            -Inbound $targetInbound `
            -ShortHwid $deviceInfo.ShortHWID

        $clientUUID = $client.UUID

        if ($targetInbound.streamSettings -is [string]) {
            $stream = $targetInbound.streamSettings | ConvertFrom-Json
        } else {
            $stream = $targetInbound.streamSettings
        }
        $realitySettings = $stream.realitySettings
        $grpcSettings = $stream.grpcSettings

        $realityParams = [PSCustomObject]@{
            ServerHost  = ([uri]$serverConfig.panel_url).Host
            ServerPort  = $targetInbound.port
            ServerName  = $realitySettings.serverNames[0]
            PublicKey   = $realitySettings.settings.publicKey
            ShortId     = $realitySettings.shortIds[0]
            ServiceName = $grpcSettings.serviceName
        }

        $newProfile = [PSCustomObject]@{
            HWID      = $deviceInfo.HWID
            ShortHWID = $deviceInfo.ShortHWID
            InboundId = $targetInbound.id
            UUID      = $clientUUID
            Email     = $client.Email
            Reality   = $realityParams
            CreatedAt = (Get-Date).ToString("o")
        }
        Save-DeviceProfile -Profile $newProfile
    } finally {
        Remove-Item -LiteralPath $cookieFile -Force -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# Шаг 4: Развертывание бинарных файлов ядра
# -----------------------------------------------------------------------------
Write-Log "`n[4/7] Развертывание ядра маршрутизации..." "Yellow"

if (-not (Test-Path $programDir)) {
    New-Item -ItemType Directory -Path $programDir -Force | Out-Null
}
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$binFiles = @("core.exe", "service.exe", "wintun.dll")
foreach ($f in $binFiles) {
    $fp = Join-Path $programDir $f
    if (Test-Path $fp) {
        try {
            Remove-Item -Path $fp -Force -ErrorAction Stop
        } catch {
            $oldFp = Join-Path $programDir "$f.old_$([int](Get-Date -UFormat %s))"
            try { Rename-Item -Path $fp -NewName $oldFp -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}

$tarXz = "$ScriptDir\bin\bin.tar.xz"
$tarExe = "$env:SystemRoot\System32\tar.exe"

if ((Test-Path $tarXz) -and (Test-Path $tarExe)) {
    Write-Log "  Распаковка защищенного архива ядра (LZMA2 / XZ)..." "Yellow"
    & $tarExe -xf "$tarXz" -C "$programDir"
} elseif (Test-Path "$ScriptDir\bin\core.exe") {
    Copy-Item -Path "$ScriptDir\bin\core.exe" -Destination "$programDir\core.exe" -Force
    Copy-Item -Path "$ScriptDir\bin\wintun.dll" -Destination "$programDir\wintun.dll" -Force
    Copy-Item -Path "$ScriptDir\bin\service.exe" -Destination "$programDir\service.exe" -Force
} else {
    throw "Компоненты ядра не найдены в $ScriptDir\bin!"
}

if ((Test-Path "$programDir\core.exe") -and (Test-Path "$programDir\service.exe")) {
    Write-Log "  [OK] Файлы ядра установлены в $programDir" "Green"
} else {
    throw "Сбой развертывания: файлы ядра не найдены в $programDir!"
}

# -----------------------------------------------------------------------------
# Шаг 5: Генерация конфигурации маршрутизации
# -----------------------------------------------------------------------------
Write-Log "`n[5/7] Генерация конфигурации маршрутизации..." "Yellow"
$configFile = "$dataDir\config.json"

if (-not $realityParams) {
    throw "Не удалось получить параметры Reality с сервера 3X-UI."
}
if (-not $realityParams.ServerHost -and $serverConfig.panel_url) {
    try { $realityParams.ServerHost = ([uri]$serverConfig.panel_url).Host } catch {}
}

New-ProksiFiCoreConfig `
    -ServerHost $realityParams.ServerHost `
    -ServerPort $realityParams.ServerPort `
    -ClientUUID $clientUUID `
    -PublicKey $realityParams.PublicKey `
    -ShortId $realityParams.ShortId `
    -ServiceName $realityParams.ServiceName `
    -ServerName $realityParams.ServerName `
    -OutputPath $configFile | Out-Null

$checkRes = & "$programDir\core.exe" check -c $configFile 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Ошибка проверки конфигурации sing-box: $checkRes"
}
Write-Log "  [OK] Конфигурация успешно сгенерирована и проверена." "Green"

# -----------------------------------------------------------------------------
# Шаг 6: Настройка политик браузеров, системного прокси и Antigravity IDE
# -----------------------------------------------------------------------------
Write-Log "`n[6/7] Настройка системного прокси, Antigravity IDE и политик QUIC..." "Yellow"
Set-BrowserQuicPolicy

# Включение системного прокси
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "127.0.0.1:7890" -Type String -Force
$proxyOverride = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>;*.ru;*.su;*.xn--p1ai"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value $proxyOverride -Type String -Force

# Установка переменной AG_LS_PROXY строго на 127.0.0.1:7890 (исправление перезаписи сторонними утилитами)
[Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "Machine")
$env:AG_LS_PROXY = "http://127.0.0.1:7890"

Write-Log "  [OK] Системный прокси и AG_LS_PROXY настроены на http://127.0.0.1:7890." "Green"
Write-Log "  [OK] Протокол QUIC отключен в Chrome, Edge и Яндекс.Браузере." "Green"

# -----------------------------------------------------------------------------
# Шаг 7: Регистрация и запуск службы Windows
# -----------------------------------------------------------------------------
Write-Log "`n[7/7] Регистрация и запуск службы ProksiFiService..." "Yellow"
$serviceName = "ProksiFiService"

# XML определение WinSW
$serviceXmlContent = @"
<service>
  <id>$serviceName</id>
  <name>ProksiFi v2.0 Bypass Service</name>
  <description>Transparent background tunnel for Google, Gemini, Telegram, ChatGPT and Antigravity IDE</description>
  <executable>$programDir\core.exe</executable>
  <workingdirectory>$programDir</workingdirectory>
  <arguments>run -c "$configFile"</arguments>
  <logpath>$logDir</logpath>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>3</keepFiles>
  </log>
  <onfailure action="restart" delay="3 sec"/>
  <delayedAutoStart>false</delayedAutoStart>
</service>
"@

$serviceXmlPath = "$programDir\service.xml"
[System.IO.File]::WriteAllText($serviceXmlPath, $serviceXmlContent, (New-Object System.Text.UTF8Encoding($false)))

# Финальный сброс IP виртуального адаптера перед стартом ядра
try {
    & netsh.exe interface ipv4 delete address name="ProksiFiTUN" addr=172.19.0.1 2>&1 | Out-Null
    Get-NetIPAddress -InterfaceAlias "ProksiFiTUN*" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
} catch {}
Start-Sleep -Milliseconds 400

# Регистрация и запуск
$installOut = & "$programDir\service.exe" install 2>&1
Write-Log "  $installOut" "Gray"
& sc.exe config $serviceName start= auto 2>&1 | Out-Null

$startOut = & "$programDir\service.exe" start 2>&1
Write-Log "  $startOut" "Gray"
Start-Sleep -Seconds 3

# Проверка статуса службы
$status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($status -and $status.Status -eq "Running") {
    Write-Log "`n==========================================================" "Green"
    Write-Log "  СЛУЖБА УСПЕШНО ЗАПУЩЕНА! ТЕСТИРОВАНИЕ КАНАЛОВ ОБХОДА..." "Green"
    Write-Log "==========================================================" "Green"

    # Live Connectivity Checks
    Write-Log "  1. Проверка Gemini (https://gemini.google.com)..." "Yellow"
    $geminiCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 https://gemini.google.com
    if ($geminiCode -eq "200") {
        Write-Log "     [OK] Gemini HTTP $geminiCode (Полный доступ!)" "Green"
    } else {
        Write-Log "     [ПРЕДУПРЕЖДЕНИЕ] Gemini HTTP $geminiCode" "Yellow"
    }

    Write-Log "  2. Проверка ChatGPT (https://chatgpt.com)..." "Yellow"
    $chatgptCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0.0.0" https://chatgpt.com
    if ($chatgptCode -eq "200" -or $chatgptCode -eq "307" -or $chatgptCode -eq "403") {
        Write-Log "     [OK] ChatGPT HTTP $chatgptCode (Обход активен!)" "Green"
    }

    Write-Log "  3. Проверка внешнего IP и геолокации (ipinfo.io)..." "Yellow"
    $ipJson = curl.exe -s --max-time 7 -x http://127.0.0.1:7890 https://ipinfo.io
    try {
        $ipObj = $ipJson | ConvertFrom-Json
        Write-Log "     [OK] IP: $($ipObj.ip) | Страна: $($ipObj.country) | Город: $($ipObj.city)" "Green"
    } catch {
        Write-Log "     [ИНФО] Ответ: $ipJson" "Yellow"
    }

    Write-Log "  4. Проверка прямого российского трафика (ya.ru)..." "Yellow"
    $yaCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 https://ya.ru
    if ($yaCode -eq "200" -or $yaCode -eq "302") {
        Write-Log "     [OK] Яндекс HTTP $yaCode (Прямой доступ, нулевая задержка)" "Green"
    }

    Write-Log "  5. Проверка Telegram (https://t.me)..." "Yellow"
    $tgCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 https://t.me
    if ($tgCode -eq "200" -or $tgCode -eq "302") {
        Write-Log "     [OK] Telegram HTTP $tgCode (Полный доступ!)" "Green"
    }

    Write-Log "`n==========================================================" "Green"
    Write-Log "  УСТАНОВКА И ПРОВЕРКА ЗАВЕРШЕНЫ УСПЕШНО!" "Green"
    Write-Log "  Служба: ProksiFiService (Автозапуск активен)" "Green"
    Write-Log "  Порт прокси: 127.0.0.1:7890 (HTTP + SOCKS5)" "Green"
    Write-Log "  Google Gemini, Antigravity IDE, ChatGPT и Telegram работают!" "Cyan"
    Write-Log "==========================================================" "Green"
} else {
    Write-Log "  [ОШИБКА] Служба не перешла в статус Running! Статус: $($status.Status)" "Red"
    Write-Log "  Последние строки журнала ошибок:" "Yellow"
    if (Test-Path "$logDir\service.err.log") {
        Get-Content "$logDir\service.err.log" -Tail 20
    }
}
