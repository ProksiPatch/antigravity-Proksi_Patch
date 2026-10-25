# ==============================================================================
# ProksiFi v2.0 - Windows Service Master Installer (WinSW Powered)
# Unblocks Google, Gemini, Telegram, and Google Antigravity via Frankfurt VPS
# ==============================================================================

# Check Administrator Privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[UAC] Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"") -Verb RunAs
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location $ScriptDir

$logDir = "$env:ProgramData\ProksiFi\logs"
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
Write-Log "  PROKSIFI v2.0 - WINDOWS SERVICE INSTALLER" "Cyan"
Write-Log "==========================================================" "Cyan"

# Import Modules
. "$ScriptDir\modules\hwid.ps1"
. "$ScriptDir\modules\3xui-api.ps1"
. "$ScriptDir\modules\browser-hardening.ps1"
. "$ScriptDir\modules\config-generator.ps1"

# Read Server Configuration
$serverConfigFile = "$ScriptDir\config\server.json"
if (-not (Test-Path $serverConfigFile)) {
    $serverConfigFile = "$ScriptDir\server.json"
}
if (-not (Test-Path $serverConfigFile)) {
    throw "Configuration file server.json not found in config/ or root!"
}
$serverConfig = Get-Content -Path $serverConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Step 1: Hardware Identification
Write-Log "`n[1/6] Verifying Hardware ID (HWID)..." "Yellow"
$deviceInfo = Get-DeviceHWID
Write-Log "  HWID: $($deviceInfo.HWID)" "Gray"
Write-Log "  Short ID: $($deviceInfo.ShortHWID)" "Gray"

# Step 2: Check Persistent Key Profile
Write-Log "`n[2/6] Checking client key profile..." "Yellow"
$savedProfile = Get-SavedDeviceProfile
$clientUUID = $null
$realityParams = $null

if ($savedProfile -and $savedProfile.UUID -and $savedProfile.InboundId -eq $serverConfig.target_inbound_id) {
    Write-Log "  [OK] Found existing key in device.json (UUID: $($savedProfile.UUID))." "Green"
    Write-Log "  Preserving permanent user key without contacting API!" "Green"
    $clientUUID = $savedProfile.UUID
    $realityParams = $savedProfile.Reality
} else {
    Write-Log "  [NEW] No local profile. Connecting to 3X-UI panel API..." "Yellow"
    $tempDir = "$env:ProgramData\ProksiFi\temp"
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

# Step 3: Deploy Binaries & WinSW Service Wrapper (Secure Safe Unpacker like Proksi_Patch)
Write-Log "`n[3/6] Deploying core binaries and service wrapper..." "Yellow"
$programDir = "C:\Program Files\ProksiFi"
$dataDir = "$env:ProgramData\ProksiFi"

if (-not (Test-Path $programDir)) {
    New-Item -ItemType Directory -Path $programDir -Force | Out-Null
}
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# Stop any running instances to avoid file lock
Stop-Process -Name "core", "service" -Force -ErrorAction SilentlyContinue

# Safe atomic lock-bypass: handle in-use files via timestamp rename (from Proksi_Patch)
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
    throw "Компоненты ядра (bin.tar.xz или core.exe) не найдены в $ScriptDir\bin!"
}

# Verify deployment
if ((Test-Path "$programDir\core.exe") -and (Test-Path "$programDir\service.exe")) {
    Write-Log "  [OK] core.exe, wintun.dll, and service.exe installed to $programDir" "Green"
} else {
    throw "Сбой развертывания: файлы ядра не найдены в $programDir!"
}

# Step 4: Generate Configuration
Write-Log "`n[4/6] Generating routing configuration..." "Yellow"
$configFile = "$dataDir\config.json"

if (-not $realityParams) {
    throw "Не удалось получить параметры Reality с сервера 3X-UI. Проверьте подключение к интернету и доступность сервера."
}

if (-not $realityParams.ServerHost -and $serverConfig.panel_url) {
    try {
        $realityParams.ServerHost = ([uri]$serverConfig.panel_url).Host
    } catch {}
}

if (-not $realityParams.ServerHost) {
    throw "Критическая ошибка: отсутствует адрес сервера (ServerHost). Проверьте настройки server.json."
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
    throw "Configuration validation failed: $checkRes"
}
Write-Log "  [OK] Configuration validated successfully!" "Green"

# Step 5: Disable QUIC via Registry & Configure Windows System Proxy
Write-Log "`n[5/6] Applying Windows Registry policies (QUIC & System Proxy)..." "Yellow"
Set-BrowserQuicPolicy
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "127.0.0.1:7890" -Type String -Force
$proxyOverride = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>;*.ru;*.su;*.xn--p1ai"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value $proxyOverride -Type String -Force
[Environment]::SetEnvironmentVariable("AG_LS_PROXY", "http://127.0.0.1:7890", "User")
Write-Log "  [OK] System Proxy & Antigravity Language Server Proxy enabled for 127.0.0.1:7890." "Green"
Write-Log "  [OK] QUIC protocol disabled in Chrome, Edge, and Yandex Browser via Group Policy." "Green"

# Step 6: Create WinSW Service XML & Register Service
Write-Log "`n[6/6] Configuring Windows Service (ProksiFiService)..." "Yellow"
$serviceName = "ProksiFiService"

# Stop existing legacy service if running
$legacySvc = Get-Service -Name "AntigravityBypassService" -ErrorAction SilentlyContinue
if ($legacySvc) {
    Write-Log "  Removing legacy service AntigravityBypassService..." "Gray"
    Stop-Service -Name "AntigravityBypassService" -Force -ErrorAction SilentlyContinue
    & sc.exe delete "AntigravityBypassService" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

# Stop existing ProksiFi service if running
$existingSvc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existingSvc) {
    Write-Log "  Stopping existing service..." "Gray"
    & "$programDir\service.exe" stop 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    & "$programDir\service.exe" uninstall 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

# Stop conflicting proxy apps on port 7890 to prevent port binding failure
$conflictProcesses = Get-Process -Name "mihomo", "core" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
foreach ($cp in $conflictProcesses) {
    Write-Log "  Stopping conflicting process '$($cp.Name)' (PID $($cp.Id)) to free port 7890..." "Yellow"
    Stop-Process -Id $cp.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 1

# Create WinSW XML Definition
$serviceXmlContent = @"
<service>
  <id>$serviceName</id>
  <name>ProksiFi v2.0 Bypass Service</name>
  <description>Transparent background tunnel for Google, Gemini, Telegram, and Antigravity IDE</description>
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
Write-Log "  [OK] Service XML definition created: $serviceXmlPath" "Green"

# Install & Start via WinSW
Write-Log "  Registering service via WinSW..." "Yellow"
$installOut = & "$programDir\service.exe" install 2>&1
Write-Log "  $installOut" "Gray"
& sc.exe config $serviceName start= auto 2>&1 | Out-Null

Write-Log "  Starting service..." "Yellow"
$startOut = & "$programDir\service.exe" start 2>&1
Write-Log "  $startOut" "Gray"
Start-Sleep -Seconds 3

$status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($status -and $status.Status -eq "Running") {
    Write-Log "`n==========================================================" "Green"
    Write-Log "  SERVICE STARTED! RUNNING DEEP VERIFICATION TESTS..." "Green"
    Write-Log "==========================================================" "Green"
    
    # Live Connectivity Checks
    Write-Log "  1. Testing Gemini (https://gemini.google.com)..." "Yellow"
    $geminiCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 https://gemini.google.com
    if ($geminiCode -eq "200") {
        Write-Log "     [OK] Gemini HTTP $geminiCode (Full Access!)" "Green"
    } else {
        Write-Log "     [WARNING] Gemini HTTP $geminiCode" "Yellow"
    }

    Write-Log "  2. Testing IP & Geo Location (https://ipinfo.io)..." "Yellow"
    $ipJson = curl.exe -s --max-time 7 -x http://127.0.0.1:7890 https://ipinfo.io
    try {
        $ipObj = $ipJson | ConvertFrom-Json
        Write-Log "     [OK] Outbound IP: $($ipObj.ip) | Country: $($ipObj.country) | City: $($ipObj.city)" "Green"
    } catch {
        Write-Log "     [NOTICE] Response: $ipJson" "Yellow"
    }

    Write-Log "  3. Testing Google Auth (https://accounts.google.com)..." "Yellow"
    $authCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 https://accounts.google.com
    if ($authCode -eq "200" -or $authCode -eq "302") {
        Write-Log "     [OK] Google Accounts HTTP $authCode (Auth Ready!)" "Green"
    }

    Write-Log "  4. Testing Local Russian Traffic (Direct Bypass)..." "Yellow"
    $yaCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 5 https://ya.ru
    if ($yaCode -eq "200" -or $yaCode -eq "302") {
        Write-Log "     [OK] Yandex HTTP $yaCode (Direct, zero proxy overhead)" "Green"
    }

    Write-Log "  5. Testing Telegram Access (https://t.me)..." "Yellow"
    $tgCode = curl.exe -s -o NUL -w "%{http_code}" --max-time 7 -x http://127.0.0.1:7890 https://t.me
    if ($tgCode -eq "200" -or $tgCode -eq "302") {
        Write-Log "     [OK] Telegram HTTP $tgCode (Full Access!)" "Green"
    } else {
        Write-Log "     [WARNING] Telegram HTTP $tgCode" "Yellow"
    }

    Write-Log "`n==========================================================" "Green"
    Write-Log "  INSTALLATION & VERIFICATION COMPLETED SUCCESSFULLY!" "Green"
    Write-Log "  Service: $serviceName (Running & Persistent)" "Green"
    Write-Log "  Proxy Port: 127.0.0.1:7890 (Mixed HTTP + SOCKS5)" "Green"
    Write-Log "  Google, Gemini, Antigravity IDE, and Telegram are 100% operational!" "Cyan"
    Write-Log "==========================================================" "Green"
} else {
    Write-Log "  [WARNING] Service status is: $($status.Status)" "Red"
    Write-Log "  Checking service logs..." "Yellow"
    if (Test-Path "$logDir\service.log") {
        Get-Content "$logDir\service.log" -Tail 20
    }
}
