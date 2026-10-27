# ==============================================================================
# Module: 3xui-api.ps1
# Description: 3X-UI Panel REST API Client
# ==============================================================================

function Invoke-3XUILogin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$PanelUrl,
        [Parameter(Mandatory = $true)] [string]$BasePath,
        [Parameter(Mandatory = $true)] [string]$Username,
        [Parameter(Mandatory = $true)] [string]$Password,
        [Parameter(Mandatory = $true)] [string]$CookieFile
    )

    $rootUrl = "$PanelUrl$BasePath/"
    $loginUrl = "$PanelUrl$BasePath/login"

    $htmlOutput = (& curl.exe -s -c "$CookieFile" -m 10 $rootUrl) -join "`n"
    $m = [regex]::Match($htmlOutput, 'name="csrf-token" content="([^"]+)"')
    if (-not $m.Success) {
        throw "Failed to extract CSRF token from $rootUrl"
    }
    $csrfToken = $m.Groups[1].Value

    $loginResponse = & curl.exe -s -b "$CookieFile" -c "$CookieFile" -X POST $loginUrl `
        -H "Content-Type: application/x-www-form-urlencoded" `
        -H "X-CSRF-Token: $csrfToken" `
        -H "Referer: $rootUrl" `
        --data-urlencode "username=$Username" `
        --data-urlencode "password=$Password" `
        -m 10

    $loginJson = $loginResponse | ConvertFrom-Json
    if (-not $loginJson.success) {
        throw "3X-UI login failed: $($loginJson.msg)"
    }

    Write-Host "[3X-UI] Successfully authenticated in panel!" -ForegroundColor Green
    return @{
        CookieFile = $CookieFile
        CsrfToken  = $csrfToken
        PanelUrl   = $PanelUrl
        BasePath   = $BasePath
    }
}

function Get-3XUIInbounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Session
    )

    $listUrl = "$($Session.PanelUrl)$($Session.BasePath)/panel/api/inbounds/list"
    $response = & curl.exe -s -b "$($Session.CookieFile)" -m 10 $listUrl
    $json = $response | ConvertFrom-Json
    if (-not $json.success) {
        throw "Failed to fetch inbounds: $($json.msg)"
    }
    return $json.obj
}

function Get-TargetInbound {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [array]$Inbounds,
        [int]$TargetId = 9,
        [string]$TargetRemark = "Germany_NextGen_gRPC"
    )

    $target = $Inbounds | Where-Object { $_.id -eq $TargetId }
    if (-not $target) {
        $target = $Inbounds | Where-Object { $_.remark -eq $TargetRemark }
    }

    if (-not $target) {
        throw "Target inbound (ID: $TargetId, Remark: $TargetRemark) not found on server!"
    }
    return $target
}

function Get-OrCreateInboundClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Session,
        [Parameter(Mandatory = $true)] [PSCustomObject]$Inbound,
        [Parameter(Mandatory = $true)] [string]$ShortHwid
    )

    $targetEmail = "client_$ShortHwid"

    # Fetch latest inbound data directly from server
    $getUrl = "$($Session.PanelUrl)$($Session.BasePath)/panel/api/inbounds/get/$($Inbound.id)"
    $getResp = & curl.exe -s -b "$($Session.CookieFile)" $getUrl
    $freshInbound = ($getResp | ConvertFrom-Json).obj
    if (-not $freshInbound) {
        $freshInbound = $Inbound
    }

    if ($freshInbound.settings -is [string]) {
        $settings = $freshInbound.settings | ConvertFrom-Json
    } else {
        $settings = $freshInbound.settings
    }

    # 1. Check if client with this HWID already exists on the server
    $existingClient = $settings.clients | Where-Object { $_.email -eq $targetEmail -or $_.email -eq "antigravity_$ShortHwid" }
    if ($existingClient) {
        Write-Host "  [3X-UI] Existing client key found on server for this device!" -ForegroundColor Green
        Write-Host "  [3X-UI] Email: $($existingClient.email) | UUID: $($existingClient.id)" -ForegroundColor Cyan
        Write-Host "  [3X-UI] Permanent key preserved and connected." -ForegroundColor Green
        return [PSCustomObject]@{
            UUID    = $existingClient.id
            Email   = $existingClient.email
            IsNew   = $false
        }
    }

    # 2. If client does NOT exist on the server, create a new persistent client in 3X-UI panel!
    Write-Host "  [3X-UI] New device (HWID: $ShortHwid). Creating client in 3X-UI panel..." -ForegroundColor Yellow
    $newUUID = [guid]::NewGuid().ToString()
    $newSubId = [guid]::NewGuid().ToString()

    $newClientObj = @{
        id         = $newUUID
        flow       = ""
        email      = $targetEmail
        totalGB    = 0
        expiryTime = 0
        enable     = $true
        tgId       = 0
        subId      = $newSubId
        reset      = 0
    }

    $allClients = @($settings.clients) + $newClientObj
    $settings.clients = $allClients

    $freshInbound.settings = $settings | ConvertTo-Json -Depth 10 -Compress

    $tempDir = "$env:ProgramData\ProksiFi\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    if ($freshInbound.streamSettings -isnot [string]) {
        $freshInbound.streamSettings = $freshInbound.streamSettings | ConvertTo-Json -Depth 10 -Compress
    }
    if ($freshInbound.sniffing -isnot [string]) {
        $freshInbound.sniffing = $freshInbound.sniffing | ConvertTo-Json -Depth 10 -Compress
    }

    $inboundJson = $freshInbound | ConvertTo-Json -Depth 10
    $tempBodyFile = "$tempDir\inbound_add_$([guid]::NewGuid().ToString('N')).json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempBodyFile, $inboundJson, $utf8NoBom)

    $updateUrl = "$($Session.PanelUrl)$($Session.BasePath)/panel/api/inbounds/update/$($Inbound.id)"
    try {
        $updateResp = & curl.exe -s -b "$($Session.CookieFile)" -c "$($Session.CookieFile)" -X POST $updateUrl `
            -H "Content-Type: application/json" `
            -H "X-CSRF-Token: $($Session.CsrfToken)" `
            --data-binary "@$tempBodyFile" `
            -m 15

        $resObj = $updateResp | ConvertFrom-Json
        if (-not $resObj.success) {
            throw "3X-UI panel update failed: $($resObj.msg)"
        }
        Write-Host "  [3X-UI] Client connection created on server: $targetEmail" -ForegroundColor Green
        Write-Host "  [3X-UI] Personal UUID: $newUUID" -ForegroundColor Cyan
    } finally {
        Remove-Item -LiteralPath $tempBodyFile -Force -ErrorAction SilentlyContinue
    }

    return [PSCustomObject]@{
        UUID    = $newUUID
        Email   = $targetEmail
        IsNew   = $true
    }
}
