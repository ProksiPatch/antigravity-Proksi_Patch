# ==============================================================================
# Module: hwid.ps1
# Description: Hardware identification and persistent profile management
# ==============================================================================

function Get-DeviceHWID {
    [CmdletBinding()]
    param()

    try {
        $machineGuid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -ErrorAction Stop).MachineGuid
    } catch {
        $machineGuid = "UNKNOWN-GUID"
    }

    try {
        $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
        $boardSerial = $baseBoard.SerialNumber.Trim()
    } catch {
        $boardSerial = "UNKNOWN-BOARD"
    }

    $rawHWID = "$machineGuid|$boardSerial"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($rawHWID)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($bytes)
    $hwid = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLower()
    $shortHwid = $hwid.Substring(0, 8)

    return [PSCustomObject]@{
        HWID        = $hwid
        ShortHWID   = $shortHwid
        MachineGuid = $machineGuid
        BoardSerial = $boardSerial
    }
}

function Get-DeviceProfilePath {
    $storageDir = Join-Path $env:ProgramData "ProksiFi"
    if (-not (Test-Path $storageDir)) {
        New-Item -ItemType Directory -Path $storageDir -Force | Out-Null
    }
    $newProfile = Join-Path $storageDir "device.json"
    $legacyProfile = Join-Path $env:ProgramData "AntigravityBypass\device.json"
    if (-not (Test-Path $newProfile) -and (Test-Path $legacyProfile)) {
        Copy-Item -Path $legacyProfile -Destination $newProfile -Force
    }
    return $newProfile
}

function Get-SavedDeviceProfile {
    [CmdletBinding()]
    param()

    $profilePath = Get-DeviceProfilePath
    if (Test-Path $profilePath) {
        try {
            $rawJson = Get-Content -Path $profilePath -Raw -Encoding UTF8
            $profile = $rawJson | ConvertFrom-Json
            return $profile
        } catch {
            Write-Warning "Failed to read device.json: $_"
            return $null
        }
    }
    return $null
}

function Save-DeviceProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Profile
    )

    $profilePath = Get-DeviceProfilePath
    $json = $Profile | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($profilePath, $json, [System.Text.Encoding]::UTF8)
    Write-Host "[HWID] Profile saved to: $profilePath" -ForegroundColor Green
}
