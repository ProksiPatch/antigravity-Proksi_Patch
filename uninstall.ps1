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
Write-Host "  PROKSIFI v2.0 - COMPLETE SYSTEM UNINSTALLER" -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red

$serviceNames = @("ProksiFiService", "AntigravityBypassService")
$programDirs = @("C:\Program Files\ProksiFi", "C:\Program Files\AntigravityBypass")
$dataDirs = @("$env:ProgramData\ProksiFi", "$env:ProgramData\AntigravityBypass")

# Step 1: Stop Services & Forcefully Terminate Core Processes
Write-Host "`n[1/5] Stopping services and terminating processes..." -ForegroundColor Yellow

# Stop WinSW services
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

# Forcefully kill all instances of core, service, and mihomo
& taskkill.exe /F /IM core.exe /T 2>&1 | Out-Null
& taskkill.exe /F /IM service.exe /T 2>&1 | Out-Null
& taskkill.exe /F /IM mihomo.exe /T 2>&1 | Out-Null

$lingeringProcesses = Get-Process -Name "core", "service", "mihomo" -ErrorAction SilentlyContinue
foreach ($p in $lingeringProcesses) {
    try {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Terminate lingering ProksiFi GUI/tray instances (except the caller process)
$proksiProcesses = Get-Process -Name "ProksiFi*" -ErrorAction SilentlyContinue
foreach ($pp in $proksiProcesses) {
    if ($CallerPID -gt 0 -and $pp.Id -eq $CallerPID) {
        continue
    }
    if ($pp.Id -eq $PID) {
        continue
    }
    try {
        Write-Host "  Closing lingering ProksiFi GUI process (PID $($pp.Id))..." -ForegroundColor Gray
        Stop-Process -Id $pp.Id -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Disable and reset virtual TUN network adapters
Get-NetAdapter -Name "ProksiFiTUN*", "AntigravityTUN*" -ErrorAction SilentlyContinue | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "  [OK] Core engine and services stopped." -ForegroundColor Green

# Step 2: Delete Windows Services
Write-Host "`n[2/5] Deleting Windows Services..." -ForegroundColor Yellow
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
Write-Host "  [OK] Services successfully unregistered." -ForegroundColor Green

# Step 3: Remove Browser Registry Policies (QUIC) & Reset System Proxy
Write-Host "`n[3/5] Restoring browser QUIC settings & turning off System Proxy..." -ForegroundColor Yellow
try {
    if (Get-Command Remove-BrowserQuicPolicy -ErrorAction SilentlyContinue) {
        Remove-BrowserQuicPolicy
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value "" -Type String -Force -ErrorAction SilentlyContinue
    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "User")
    [Environment]::SetEnvironmentVariable("AG_LS_PROXY", $null, "Machine")
    Write-Host "  [OK] Browser QUIC policies removed, System Proxy disabled, and AG_LS_PROXY reset." -ForegroundColor Green
} catch {
    Write-Warning "Could not reset browser policies: $_"
}

# Step 4: Delete Program Files
Write-Host "`n[4/5] Removing system binaries from Program Files..." -ForegroundColor Yellow
foreach ($pDir in $programDirs) {
    if (Test-Path -LiteralPath $pDir) {
        Remove-Item -LiteralPath $pDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Removed directory: $pDir" -ForegroundColor Green
    }
}

# Step 5: Wipe ProgramData (Device Profile, Config, Logs)
Write-Host "`n[5/5] Wiping data directories (device.json, configs, logs)..." -ForegroundColor Yellow
Set-Location -LiteralPath $env:TEMP
foreach ($dDir in $dataDirs) {
    if (Test-Path -LiteralPath $dDir) {
        Remove-Item -LiteralPath $dDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Removed persistent data: $dDir" -ForegroundColor Green
    }
}

# Clean temp staging directory if exists
$tempSetup = Join-Path $env:TEMP "ProksiFi_Setup"
if (Test-Path -LiteralPath $tempSetup) {
    Remove-Item -LiteralPath $tempSetup -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  PROKSIFI v2.0 FULLY REMOVED FROM SYSTEM!" -ForegroundColor Green
Write-Host "  The system is 100% clean and ready for a fresh install." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
