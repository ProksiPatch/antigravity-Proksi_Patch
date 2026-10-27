# ==============================================================================
# Module: browser-hardening.ps1
# Description: Disables QUIC (UDP 443) in Google Chrome and Microsoft Edge via Windows Registry
# ==============================================================================

function Set-BrowserQuicPolicy {
    [CmdletBinding()]
    param()

    $targets = @(
        @{ Name = "Google Chrome"; Path = "HKLM:\SOFTWARE\Policies\Google\Chrome" },
        @{ Name = "Microsoft Edge"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge" },
        @{ Name = "Yandex Browser"; Path = "HKLM:\SOFTWARE\Policies\YandexBrowser" },
        @{ Name = "Yandex Browser (Alt)"; Path = "HKLM:\SOFTWARE\Policies\Yandex\YandexBrowser" }
    )

    foreach ($target in $targets) {
        if (-not (Test-Path $target.Path)) {
            New-Item -Path $target.Path -Force | Out-Null
        }
        Set-ItemProperty -Path $target.Path -Name "QuicAllowed" -Value 0 -Type DWord -Force
        Write-Host "[QUIC-Patch] Disabled QUIC for $($target.Name) (QuicAllowed = 0)" -ForegroundColor Green
    }
}

function Remove-BrowserQuicPolicy {
    [CmdletBinding()]
    param()

    $targets = @(
        @{ Name = "Google Chrome"; Path = "HKLM:\SOFTWARE\Policies\Google\Chrome" },
        @{ Name = "Microsoft Edge"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge" },
        @{ Name = "Yandex Browser"; Path = "HKLM:\SOFTWARE\Policies\YandexBrowser" },
        @{ Name = "Yandex Browser (Alt)"; Path = "HKLM:\SOFTWARE\Policies\Yandex\YandexBrowser" }
    )

    foreach ($target in $targets) {
        if (Test-Path $target.Path) {
            Remove-ItemProperty -Path $target.Path -Name "QuicAllowed" -ErrorAction SilentlyContinue
            Write-Host "[QUIC-Patch] Restored QUIC policy for $($target.Name)" -ForegroundColor Yellow
        }
    }
}

function Test-BrowserQuicPolicy {
    [CmdletBinding()]
    param()

    $chromeQuic = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "QuicAllowed" -ErrorAction SilentlyContinue).QuicAllowed
    $edgeQuic = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "QuicAllowed" -ErrorAction SilentlyContinue).QuicAllowed
    $yandexQuic = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\YandexBrowser" -Name "QuicAllowed" -ErrorAction SilentlyContinue).QuicAllowed

    return [PSCustomObject]@{
        ChromeQuicBlocked = ($chromeQuic -eq 0)
        EdgeQuicBlocked   = ($edgeQuic -eq 0)
        YandexQuicBlocked = ($yandexQuic -eq 0)
    }
}
