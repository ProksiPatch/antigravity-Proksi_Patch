# ==============================================================================
# Module: config-generator.ps1
# Description: Generates optimal sing-box 1.14+ JSON configuration with gVisor TUN and Split Routing
# ==============================================================================

function New-ProksiFiCoreConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ServerHost,
        [Parameter(Mandatory = $true)] [int]$ServerPort,
        [Parameter(Mandatory = $true)] [string]$ClientUUID,
        [Parameter(Mandatory = $true)] [string]$PublicKey,
        [Parameter(Mandatory = $true)] [string]$ShortId,
        [Parameter(Mandatory = $true)] [string]$ServiceName,
        [Parameter(Mandatory = $true)] [string]$ServerName,
        [string]$OutputPath = "$env:ProgramData\ProksiFi\config.json"
    )

    $targetDomains = @(
        "google.com",
        "google.ru",
        "google.de",
        "gmail.com",
        "googlemail.com",
        "gemini.google.com",
        "aistudio.google.com",
        "notebooklm.google.com",
        "googleapis.com",
        "generativelanguage.googleapis.com",
        "alkalimakersuite-pa.clients6.google.com",
        "google",
        "goog",
        "run.app",
        "appspot.com",
        "google.dev",
        "google.org",
        "google.net",
        "withgoogle.com",
        "googlelabs.com",
        "cloud.google.com",
        "googlecloud.com",
        "antigravity.google",
        "deepmind.google",
        "generativeai.google",
        "about.google",
        "gstatic.com",
        "googleusercontent.com",
        "googlevideo.com",
        "youtube.com",
        "ytimg.com",
        "ggpht.com",
        "gvt1.com",
        "gvt2.com",
        "gvt3.com",
        "1e100.net",
        "doubleclick.net",
        "googleadservices.com",
        "google-analytics.com",
        "googletagmanager.com",
        "recaptcha.net",
        "g.co",
        "goo.gl",
        "android.com",
        "clients6.google.com",
        "cloudaicompanion.googleapis.com",
        "cloudcode-pa.googleapis.com",
        "daily-cloud-pa.clients6.google.com",
        "developerprofiles.google.com",
        "firebase.google.com",
        "vscode-cdn.net",
        "marketplace.visualstudio.com",
        "gallerycdn.vsassets.io",
        "github.com",
        "githubusercontent.com",
        "githubcopilot.com",
        "githubassets.com",
        "github.githubassets.com",
        "cloudflare.com",
        "cdnjs.cloudflare.com",
        "pki.goog",
        "ocsp.pki.goog",
        "crl.pki.goog",
        "googletagservices.com",
        "ipinfo.io",
        "virustotal.com",
        "www.virustotal.com",
        "browserleaks.com",
        "whoer.net",
        "ipleak.net",
        "t.me",
        "telegram.org",
        "telegram.me",
        "telegram.dog",
        "telegra.ph",
        "telesco.pe",
        "tdesktop.com"
    )

    $telegramCIDRs = @(
        "91.108.4.0/22",
        "91.108.8.0/22",
        "91.108.12.0/22",
        "91.108.16.0/22",
        "91.108.20.0/22",
        "91.108.56.0/22",
        "149.154.160.0/20",
        "149.154.164.0/22",
        "149.154.168.0/22",
        "149.154.172.0/22",
        "185.76.151.0/24"
    )

    $torrentProcesses = @(
        "qbittorrent.exe",
        "utorrent.exe",
        "utorrentie.exe",
        "BitTorrent.exe",
        "bittorrent.exe",
        "BitTorrentWeb.exe",
        "uTorrentWeb.exe",
        "transmission-qt.exe",
        "transmission-daemon.exe",
        "deluge.exe",
        "deluged.exe",
        "BiglyBT.exe",
        "tixati.exe",
        "BitComet.exe",
        "PicoTorrent.exe",
        "vuze.exe",
        "Tribler.exe",
        "aria2c.exe",
        "fdm.exe",
        "FreeDownloadManager.exe",
        "Motrix.exe"
    )

    $logDir = "$env:ProgramData\ProksiFi\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $serviceLogFile = Join-Path $logDir "service.log"

    $config = @{
        log = @{
            level     = "info"
            timestamp = $true
            output    = $serviceLogFile
        }
        dns = @{
            servers = @(
                @{
                    tag    = "remote-dns"
                    type   = "https"
                    server = "1.1.1.1"
                    detour = "proxy"
                },
                @{
                    tag    = "local-dns"
                    type   = "udp"
                    server = "77.88.8.8"
                }
            )
            rules = @(
                @{
                    domain = @("localhost")
                    server = "local-dns"
                },
                @{
                    process_name = $torrentProcesses
                    server       = "local-dns"
                },
                @{
                    process_name = @(
                        "Antigravity.exe",
                        "antigravity.exe",
                        "language_server.exe",
                        "agy.exe",
                        "Code.exe",
                        "Telegram.exe",
                        "telegram.exe",
                        "ag_dns.exe",
                        "AG_2.26.0.exe"
                    )
                    server = "remote-dns"
                },
                @{
                    domain_suffix = $targetDomains
                    server        = "remote-dns"
                }
            )
            strategy        = "ipv4_only"
            reverse_mapping = $true
        }
        inbounds = @(
            @{
                type           = "tun"
                tag            = "tun-in"
                interface_name = "ProksiFiTUN"
                address        = @("172.19.0.1/30")
                auto_route     = $true
                strict_route   = $true
                stack          = "gvisor"
            },
            @{
                type        = "mixed"
                tag         = "mixed-in"
                listen      = "127.0.0.1"
                listen_port = 7890
            }
        )
        outbounds = @(
            @{
                type        = "vless"
                tag         = "proxy"
                server      = $ServerHost
                server_port = $ServerPort
                uuid        = $ClientUUID
                transport   = @{
                    type                  = "grpc"
                    service_name          = $ServiceName
                    idle_timeout          = "15s"
                    ping_timeout          = "15s"
                    permit_without_stream = $false
                }
                tls         = @{
                    enabled     = $true
                    server_name = $ServerName
                    utls        = @{
                        enabled     = $true
                        fingerprint = "chrome"
                    }
                    reality     = @{
                        enabled    = $true
                        public_key = $PublicKey
                        short_id   = $ShortId
                    }
                }
            },
            @{
                type = "direct"
                tag  = "direct"
            }
        )
        route = @{
            default_domain_resolver = "local-dns"
            auto_detect_interface   = $true
            rules                   = @(
                @{
                    process_name = $torrentProcesses
                    outbound     = "direct"
                },
                @{
                    action  = "sniff"
                    sniffer = @("http", "tls", "quic")
                    timeout = "500ms"
                },
                @{
                    protocol = @("bittorrent")
                    outbound = "direct"
                },
                @{
                    port    = @(53)
                    action  = "hijack-dns"
                },
                @{
                    port    = @(443, 3478, 19302)
                    network = @("udp")
                    action  = "reject"
                },
                @{
                    ip_cidr  = @("127.0.0.0/8", "::1/128")
                    outbound = "direct"
                },
                @{
                    ip_is_private = $true
                    outbound      = "direct"
                },
                @{
                    process_name = @(
                        "Antigravity.exe",
                        "antigravity.exe",
                        "language_server.exe",
                        "agy.exe",
                        "Code.exe",
                        "Telegram.exe",
                        "telegram.exe",
                        "ag_dns.exe",
                        "AG_2.26.0.exe"
                    )
                    outbound     = "proxy"
                },
                @{
                    process_path_regex = @(
                        "(?i).*programs[\\/]antigravity.*",
                        "(?i).*\.gemini.*",
                        "(?i).*microsoft vs code.*",
                        "(?i).*ag_.*\.exe.*",
                        "(?i).*ag[0-9_\.]*\.exe.*"
                    )
                    outbound     = "proxy"
                },
                @{
                    domain_suffix = $targetDomains
                    outbound      = "proxy"
                },
                @{
                    ip_cidr  = $telegramCIDRs
                    outbound = "proxy"
                }
            )
            final                   = "direct"
        }
    }

    $json = $config | ConvertTo-Json -Depth 10
    
    $outDir = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)
    Write-Host "[Config] Configuration file generated: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

Set-Alias -Name New-AntigravityCoreConfig -Value New-ProksiFiCoreConfig -ErrorAction SilentlyContinue
