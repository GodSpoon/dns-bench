# dns-bench.ps1 — DNS Provider Performance Benchmark for Windows
# A speedtest-style CLI for DNS provider benchmarking
# https://github.com/GodSpoon/dns-bench
#
# Usage:
#   irm https://raw.githubusercontent.com/GodSpoon/dns-bench/main/dns-bench.ps1 | iex
#   .\dns-bench.ps1 [-Queries N] [-Timeout N] [-Jobs N] [-NoColor]

[CmdletBinding()]
param(
    [Alias("q")][int]$Queries = 3,
    [Alias("t")][int]$Timeout = 2,
    [Alias("j")][int]$Jobs = 10,
    [Alias("c")][string]$Category = "",
    [Alias("a")][switch]$All,
    [switch]$NoColor,
    [Alias("h")][switch]$Help
)

$Version = "2.1.0"

if ($Help) {
    Write-Host @"
dns-bench — DNS Provider Performance Benchmark (Windows)

Usage:
  .\dns-bench.ps1 [OPTIONS]

Options:
  -Queries N     Queries per domain per server (default: 3)
  -Timeout N     Query timeout in seconds (default: 2)
  -Jobs N        Parallel jobs (default: 10)
  -Category LIST Comma-separated category filter (default: interactive menu)
                 Categories: privacy, general, security, adblock, family
  -All           Benchmark all providers, skip category menu
  -NoColor       Disable colored output
  -Help          Show this help
"@
    exit 0
}

# ── Colors ────────────────────────────────────────────────────────────────────
if (-not $NoColor -and $Host.UI.SupportsVirtualTerminal) {
    $ESC = [char]27
    $RST = "$ESC[0m"
    $BLD = "$ESC[1m"
    $DIM = "$ESC[2m"
    $RED = "$ESC[38;5;196m"
    $GRN = "$ESC[38;5;46m"
    $YLW = "$ESC[38;5;226m"
    $BLU = "$ESC[38;5;33m"
    $CYN = "$ESC[38;5;51m"
    $MAG = "$ESC[38;5;165m"
    $ORG = "$ESC[38;5;208m"
    $WHT = "$ESC[38;5;255m"
    $GRY = "$ESC[38;5;244m"
    $DKGRY = "$ESC[38;5;238m"
    $GOLD = "$ESC[38;5;220m"
    $SLVR = "$ESC[38;5;250m"
    $BRNZ = "$ESC[38;5;180m"
} else {
    $RST=$BLD=$DIM=$RED=$GRN=$YLW=$BLU=$CYN=$MAG=$ORG=$WHT=$GRY=$DKGRY=$GOLD=$SLVR=$BRNZ=""
}

# ── Banner ────────────────────────────────────────────────────────────────────
function Show-Banner {
    Write-Host ""
    Write-Host "${CYN}${BLD}    +====================================================+${RST}"
    Write-Host "${CYN}${BLD}    |${RST}${WHT}${BLD}        DNS BENCH  -  Performance Benchmark          ${RST}${CYN}${BLD}|${RST}"
    Write-Host "${CYN}${BLD}    |${RST}${GRY}              Windows Edition v${Version}                ${RST}${CYN}${BLD}|${RST}"
    Write-Host "${CYN}${BLD}    +====================================================+${RST}"
    Write-Host ""
}

# ── Domains ───────────────────────────────────────────────────────────────────
$Domains = @(
    "google.com", "youtube.com", "facebook.com", "amazon.com", "wikipedia.org",
    "reddit.com", "netflix.com", "linkedin.com", "apple.com", "microsoft.com",
    "github.com", "twitter.com", "instagram.com", "tiktok.com", "ebay.com",
    "paypal.com", "yahoo.com", "cnn.com", "nytimes.com", "cloudflare.com"
)

# ── DNS Providers ─────────────────────────────────────────────────────────────
# Source: https://adguard-dns.io/kb/general/dns-providers/
# Cat: privacy, general, security, adblock, family
$AllProviders = @(
    @{ Name="AdGuard Default"; IPv4=@("94.140.14.14","94.140.15.15"); IPv6=@("2a10:50c0::ad1:ff","2a10:50c0::ad2:ff"); Cat="adblock" },
    @{ Name="AdGuard Family"; IPv4=@("94.140.14.15","94.140.15.16"); IPv6=@("2a10:50c0::bad1:ff","2a10:50c0::bad2:ff"); Cat="family" },
    @{ Name="AdGuard Non-filter"; IPv4=@("94.140.14.140","94.140.14.141"); IPv6=@("2a10:50c0::1:ff","2a10:50c0::2:ff"); Cat="general" },
    @{ Name="Google"; IPv4=@("8.8.8.8","8.8.4.4"); IPv6=@("2001:4860:4860::8888","2001:4860:4860::8844"); Cat="general" },
    @{ Name="Cloudflare"; IPv4=@("1.1.1.1","1.0.0.1"); IPv6=@("2606:4700:4700::1111","2606:4700:4700::1001"); Cat="general" },
    @{ Name="Cloudflare Malware"; IPv4=@("1.1.1.2","1.0.0.2"); IPv6=@("2606:4700:4700::1112","2606:4700:4700::1002"); Cat="security" },
    @{ Name="Cloudflare Family"; IPv4=@("1.1.1.3","1.0.0.3"); IPv6=@("2606:4700:4700::1113","2606:4700:4700::1003"); Cat="family" },
    @{ Name="Quad9"; IPv4=@("9.9.9.9","149.112.112.112"); IPv6=@("2620:fe::fe","2620:fe::fe:9"); Cat="security" },
    @{ Name="Quad9 Unsecured"; IPv4=@("9.9.9.10","149.112.112.10"); IPv6=@("2620:fe::10","2620:fe::fe:10"); Cat="general" },
    @{ Name="Quad9 ECS"; IPv4=@("9.9.9.11","149.112.112.11"); IPv6=@("2620:fe::11","2620:fe::fe:11"); Cat="security" },
    @{ Name="OpenDNS"; IPv4=@("208.67.222.222","208.67.220.220"); IPv6=@("2620:119:35::35","2620:119:53::53"); Cat="security" },
    @{ Name="OpenDNS Family"; IPv4=@("208.67.222.123","208.67.220.123"); IPv6=@(); Cat="family" },
    @{ Name="Yandex Basic"; IPv4=@("77.88.8.8","77.88.8.1"); IPv6=@("2a02:6b8::feed:0ff","2a02:6b8:0:1::feed:0ff"); Cat="general" },
    @{ Name="Yandex Safe"; IPv4=@("77.88.8.88","77.88.8.2"); IPv6=@("2a02:6b8::feed:bad","2a02:6b8:0:1::feed:bad"); Cat="security" },
    @{ Name="Yandex Family"; IPv4=@("77.88.8.3","77.88.8.7"); IPv6=@("2a02:6b8::feed:a11","2a02:6b8:0:1::feed:a11"); Cat="family" },
    @{ Name="CleanBrowsing Family"; IPv4=@("185.228.168.168","185.228.169.168"); IPv6=@("2a0d:2a00:1::","2a0d:2a00:2::"); Cat="family" },
    @{ Name="CleanBrowsing Adult"; IPv4=@("185.228.168.10","185.228.169.11"); IPv6=@("2a0d:2a00:1::1","2a0d:2a00:2::1"); Cat="family" },
    @{ Name="CleanBrowsing Security"; IPv4=@("185.228.168.9","185.228.169.9"); IPv6=@("2a0d:2a00:1::2","2a0d:2a00:2::2"); Cat="security" },
    @{ Name="Comodo Secure"; IPv4=@("8.26.56.26","8.20.247.20"); IPv6=@(); Cat="security" },
    @{ Name="Neustar R&P 1"; IPv4=@("156.154.70.1","156.154.71.1"); IPv6=@("2610:a1:1018::1","2610:a1:1019::1"); Cat="general" },
    @{ Name="Neustar R&P 2"; IPv4=@("156.154.70.5","156.154.71.5"); IPv6=@("2610:a1:1018::5","2610:a1:1019::5"); Cat="general" },
    @{ Name="Neustar Threat"; IPv4=@("156.154.70.2","156.154.71.2"); IPv6=@("2610:a1:1018::2","2610:a1:1019::2"); Cat="security" },
    @{ Name="Neustar Family"; IPv4=@("156.154.70.3","156.154.71.3"); IPv6=@("2610:a1:1018::3","2610:a1:1019::3"); Cat="family" },
    @{ Name="Neustar Business"; IPv4=@("156.154.70.4","156.154.71.4"); IPv6=@("2610:a1:1018::4","2610:a1:1019::4"); Cat="security" },
    @{ Name="Verisign"; IPv4=@("64.6.64.6","64.6.65.6"); IPv6=@("2620:74:1b::1:1","2620:74:1c::2:2"); Cat="general" },
    @{ Name="Level3"; IPv4=@("4.2.2.1","4.2.2.2"); IPv6=@(); Cat="general" },
    @{ Name="SWITCH"; IPv4=@("130.59.31.248"); IPv6=@("2001:620:0:ff::2"); Cat="privacy" },
    @{ Name="Dyn"; IPv4=@("216.146.35.35","216.146.36.36"); IPv6=@(); Cat="general" },
    @{ Name="DNS.WATCH"; IPv4=@("84.200.69.80","84.200.70.40"); IPv6=@("2001:1608:10:25::1c04:b12f","2001:1608:10:25::9249:d69b"); Cat="privacy" },
    @{ Name="SkyDNS"; IPv4=@("193.58.251.251"); IPv6=@(); Cat="security" },
    @{ Name="Comss.ru West"; IPv4=@("92.38.152.163","93.115.24.204"); IPv6=@("2a03:90c0:56::1a5","2a02:7b40:5eb0:e95d::1"); Cat="adblock" },
    @{ Name="Comss.ru East"; IPv4=@("92.223.109.31","91.230.211.67"); IPv6=@("2a03:90c0:b5::1a","2a04:2fc0:39::47"); Cat="adblock" },
    @{ Name="SafeDNS"; IPv4=@("195.46.39.39","195.46.39.40"); IPv6=@(); Cat="security" },
    @{ Name="CIRA Private"; IPv4=@("149.112.121.10","149.112.122.10"); IPv6=@("2620:10A:80BB::10","2620:10A:80BC::10"); Cat="privacy" },
    @{ Name="CIRA Protected"; IPv4=@("149.112.121.20","149.112.122.20"); IPv6=@("2620:10A:80BB::20","2620:10A:80BC::20"); Cat="security" },
    @{ Name="CIRA Family"; IPv4=@("149.112.121.30","149.112.122.30"); IPv6=@("2620:10A:80BB::30","2620:10A:80BC::30"); Cat="family" },
    @{ Name="OpenNIC"; IPv4=@("185.121.177.177","169.239.202.202"); IPv6=@("2a05:dfc7:5::53","2a05:dfc7:5353::53"); Cat="privacy" },
    @{ Name="DNS for Family"; IPv4=@("94.130.180.225","78.47.64.161"); IPv6=@("2a01:4f8:1c0c:40db::1","2a01:4f8:1c17:4df8::1"); Cat="family" },
    @{ Name="CZ.NIC ODVR"; IPv4=@("193.17.47.1","185.43.135.1"); IPv6=@("2001:148f:ffff::1","2001:148f:fffe::1"); Cat="privacy" },
    @{ Name="AliDNS"; IPv4=@("223.5.5.5","223.6.6.6"); IPv6=@("2400:3200::1","2400:3200:baba::1"); Cat="general" },
    @{ Name="CFIEC"; IPv4=@(); IPv6=@("240C::6666","240C::6644"); Cat="general" },
    @{ Name="Nawala"; IPv4=@("180.131.144.144","180.131.145.145"); IPv6=@(); Cat="family" },
    @{ Name="DNSCEPAT Asia"; IPv4=@("172.105.216.54"); IPv6=@("2400:8902::f03c:92ff:fe09:48cc"); Cat="security" },
    @{ Name="DNSCEPAT Europe"; IPv4=@("5.2.75.231"); IPv6=@("2a04:52c0:101:98d::"); Cat="security" },
    @{ Name="360 Secure"; IPv4=@("101.226.4.6","218.30.118.6"); IPv6=@(); Cat="security" },
    @{ Name="DNSPod"; IPv4=@("119.29.29.29","119.28.28.28"); IPv6=@(); Cat="general" },
    @{ Name="114DNS"; IPv4=@("114.114.114.114","114.114.115.115"); IPv6=@(); Cat="general" },
    @{ Name="Quad101"; IPv4=@("101.101.101.101","101.102.103.104"); IPv6=@("2001:de4::101","2001:de4::102"); Cat="privacy" },
    @{ Name="OneDNS Pure"; IPv4=@("117.50.10.10","52.80.52.52"); IPv6=@(); Cat="general" },
    @{ Name="OneDNS Block"; IPv4=@("117.50.11.11","52.80.66.66"); IPv6=@(); Cat="adblock" },
    @{ Name="Privacy-First SG"; IPv4=@("174.138.21.128"); IPv6=@("2400:6180:0:d0::5f6e:4001"); Cat="privacy" },
    @{ Name="Privacy-First JP"; IPv4=@("172.104.93.80"); IPv6=@("2400:8902::f03c:91ff:feda:c514"); Cat="privacy" },
    @{ Name="FreeDNS"; IPv4=@("172.104.237.57","172.104.49.100"); IPv6=@(); Cat="general" },
    @{ Name="Freenom World"; IPv4=@("80.80.80.80","80.80.81.81"); IPv6=@(); Cat="privacy" },
    @{ Name="OSZX"; IPv4=@("51.38.83.141"); IPv6=@("2001:41d0:801:2000::d64"); Cat="adblock" },
    @{ Name="PumpleX"; IPv4=@("51.38.82.198"); IPv6=@("2001:41d0:801:2000::1b28"); Cat="privacy" },
    @{ Name="Strongarm"; IPv4=@("54.174.40.213","52.3.100.184"); IPv6=@(); Cat="security" },
    @{ Name="SafeSurfer"; IPv4=@("104.155.237.225","104.197.28.121"); IPv6=@(); Cat="family" },
    @{ Name="DNS.SB"; IPv4=@("185.222.222.222","45.11.45.11"); IPv6=@("2a09::","2a11::"); Cat="privacy" },
    @{ Name="DNS Forge"; IPv4=@("176.9.93.198","176.9.1.117"); IPv6=@("2a01:4f8:151:34aa::198","2a01:4f8:141:316d::117"); Cat="adblock" },
    @{ Name="LibreDNS"; IPv4=@("88.198.92.222"); IPv6=@(); Cat="privacy" },
    @{ Name="AhaDNS NL"; IPv4=@("5.2.75.75"); IPv6=@("2a04:52c0:101:75::75"); Cat="adblock" },
    @{ Name="AhaDNS India"; IPv4=@("45.79.120.233"); IPv6=@("2400:8904:e001:43::43"); Cat="adblock" },
    @{ Name="AhaDNS LA"; IPv4=@("45.67.219.208"); IPv6=@("2a04:bdc7:100:70::70"); Cat="adblock" },
    @{ Name="AhaDNS NY"; IPv4=@("185.213.26.187"); IPv6=@("2a0d:5600:33:3::3"); Cat="adblock" },
    @{ Name="Seby"; IPv4=@("45.76.113.31"); IPv6=@(); Cat="privacy" },
    @{ Name="puntCAT"; IPv4=@("109.69.8.51"); IPv6=@("2a00:1508:0:4::9"); Cat="privacy" },
    @{ Name="DNSlify"; IPv4=@("185.235.81.1","185.235.81.2"); IPv6=@("2a0d:4d00:81::1","2a0d:4d00:81::2"); Cat="general" },
    @{ Name="NextDNS"; IPv4=@("45.90.28.0","45.90.30.0"); IPv6=@(); Cat="general" },
    @{ Name="ControlD"; IPv4=@("76.76.2.0","76.76.10.0"); IPv6=@(); Cat="security" },
    @{ Name="Mullvad"; IPv4=@("194.242.2.2"); IPv6=@(); Cat="privacy" },
    @{ Name="DNS0.eu"; IPv4=@("193.110.81.0","185.253.5.0"); IPv6=@(); Cat="security" }
)

# ── Category Definitions ─────────────────────────────────────────────────────
$CategoryMap = [ordered]@{
    "privacy"  = "Privacy-Focused / No-Log"
    "general"  = "General Purpose (Unfiltered)"
    "security" = "Security / Malware Blocking"
    "adblock"  = "Ad & Tracker Blocking"
    "family"   = "Family / Content Filtering"
}
$CategoryDescs = @{
    "privacy"  = "Minimal or zero query logging"
    "general"  = "Fast, reliable, no content blocking"
    "security" = "Blocks malicious domains & phishing"
    "adblock"  = "Strips ads and trackers"
    "family"   = "Blocks adult content & more"
}

# ── Category Selection ────────────────────────────────────────────────────────
$selectedCategory = $Category
if ($All) { $selectedCategory = "all" }

if (-not $selectedCategory -and [Environment]::UserInteractive) {
    Write-Host "  ${BLD}${CYN}> SELECT PROVIDER CATEGORIES${RST}"
    Write-Host "  ${DKGRY}$('=' * 60)${RST}"
    Write-Host ""
    Write-Host "  ${GRY}Enter numbers separated by spaces, or press ${BLD}Enter${RST}${GRY} for all:${RST}"
    Write-Host ""

    $num = 1
    foreach ($key in $CategoryMap.Keys) {
        $count = ($AllProviders | Where-Object { $_.Cat -eq $key }).Count
        Write-Host ("    ${BLD}${WHT}{0}${RST}  {1,-35} ${GRY}({2} providers)${RST}" -f $num, $CategoryMap[$key], $count)
        Write-Host "       ${DIM}${GRY}$($CategoryDescs[$key])${RST}"
        $num++
    }
    Write-Host ""
    $input_val = Read-Host "  ${BLD}${CYN}>${RST} ${BLD}Choice [1-5, or Enter=all]"

    if ([string]::IsNullOrWhiteSpace($input_val)) {
        $selectedCategory = "all"
    } else {
        $cats = @()
        $keys = @($CategoryMap.Keys)
        foreach ($n in ($input_val -split '\s+')) {
            if ($n -match '^[1-5]$') {
                $cats += $keys[[int]$n - 1]
            }
        }
        $selectedCategory = if ($cats.Count -gt 0) { $cats -join "," } else { "all" }
    }
    Write-Host ""
}
if (-not $selectedCategory) { $selectedCategory = "all" }

# Filter providers
if ($selectedCategory -eq "all") {
    $Providers = $AllProviders
    $CategoryLabel = "All categories"
} else {
    $selCats = $selectedCategory -split ","
    $Providers = $AllProviders | Where-Object { $selCats -contains $_.Cat }
    $labels = $selCats | ForEach-Object { $CategoryMap[$_] } | Where-Object { $_ }
    $CategoryLabel = $labels -join ", "
}

if ($Providers.Count -eq 0) {
    Write-Host "${RED}No providers matched the selected categories.${RST}"
    exit 1
}

# ── IPv6 Detection ────────────────────────────────────────────────────────────
$HasIPv6 = $false
try {
    $result = Resolve-DnsName -Name "google.com" -Server "2001:4860:4860::8888" -Type A -DnsOnly -ErrorAction Stop 2>$null
    if ($result) { $HasIPv6 = $true }
} catch {
    $HasIPv6 = $false
}

# ── DNS Query Function ───────────────────────────────────────────────────────
function Test-DnsLatency {
    param(
        [string]$Server,
        [string]$Domain,
        [int]$TimeoutSec
    )
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Resolve-DnsName -Name $Domain -Server $Server -Type A -DnsOnly -ErrorAction Stop
        $sw.Stop()
        return [int]$sw.ElapsedMilliseconds
    } catch {
        return -1
    }
}

# ── Benchmark a Single Provider ──────────────────────────────────────────────
function Measure-Provider {
    param(
        [hashtable]$Provider
    )

    $ips = @()
    foreach ($ip in $Provider.IPv4) { if ($ip) { $ips += $ip } }
    if ($HasIPv6) {
        foreach ($ip in $Provider.IPv6) { if ($ip) { $ips += $ip } }
    }

    $totalLatency = 0
    $resolved = 0
    $failed = 0

    if ($ips.Count -eq 0) {
        return @{
            Name = $Provider.Name
            AvgMs = 9999
            Resolved = 0
            Failed = $Domains.Count
            Reliability = 0.0
            IPv4 = ($Provider.IPv4 -join ",")
            IPv6 = ($Provider.IPv6 -join ",")
        }
    }

    foreach ($domain in $Domains) {
        $best = -1
        foreach ($ip in $ips) {
            for ($q = 0; $q -lt $Queries; $q++) {
                $latency = Test-DnsLatency -Server $ip -Domain $domain -TimeoutSec $Timeout
                if ($latency -ge 0) {
                    if ($best -lt 0 -or $latency -lt $best) {
                        $best = $latency
                    }
                }
            }
        }
        if ($best -ge 0) {
            $resolved++
            $totalLatency += $best
        } else {
            $failed++
        }
    }

    $avgMs = 9999
    if ($resolved -gt 0) { $avgMs = [int]($totalLatency / $resolved) }
    $reliability = [math]::Round(($resolved / $Domains.Count) * 100, 1)

    return @{
        Name = $Provider.Name
        AvgMs = $avgMs
        Resolved = $resolved
        Failed = $failed
        Reliability = $reliability
        IPv4 = ($Provider.IPv4 -join ",")
        IPv6 = ($Provider.IPv6 -join ",")
    }
}

# ── Render Bar ────────────────────────────────────────────────────────────────
function Get-Bar {
    param([int]$Value, [int]$MaxValue, [int]$Width, [string]$Color)
    if ($MaxValue -eq 0) { $MaxValue = 1 }
    $chars = [int](($Value / $MaxValue) * $Width)
    if ($chars -lt 1 -and $Value -gt 0) { $chars = 1 }
    if ($chars -gt $Width) { $chars = $Width }
    $bar = ([char]0x2588).ToString() * $chars
    return "${Color}${bar}${RST}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
Show-Banner

# System Info
$currentDns = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Select-Object -First 1).ServerAddresses[0]
if (-not $currentDns) { $currentDns = "unknown" }

Write-Host "  ${GRY}* System: ${WHT}Windows $([System.Environment]::OSVersion.Version)${RST}"
Write-Host "  ${GRY}* Current DNS: ${WHT}${currentDns}${RST}"
if ($HasIPv6) {
    Write-Host "  ${GRY}* IPv6: ${GRN}Available - IPv6 providers will be tested${RST}"
} else {
    Write-Host "  ${GRY}* IPv6: ${YLW}Not available - skipping IPv6-only providers${RST}"
}
Write-Host "  ${GRY}* Date: ${WHT}$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')${RST}"
Write-Host ""

$providerCount = $Providers.Count
Write-Host "  ${GRY}Testing ${BLD}${WHT}${providerCount}${RST}${GRY} providers across ${BLD}${WHT}$($Domains.Count)${RST}${GRY} domains (${Queries} queries each)${RST}"
Write-Host "  ${GRY}Timeout: ${Timeout}s | Parallel jobs: ${Jobs} | ${BLD}${WHT}${CategoryLabel}${RST}"
Write-Host ""

# Run benchmarks with parallel jobs
$results = @()
$completed = 0

# Use runspaces for parallelism
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $Jobs)
$runspacePool.Open()
$runspaces = @()

$scriptBlock = {
    param($Provider, $Domains, $Queries, $Timeout, $HasIPv6)

    function Test-DnsLatency {
        param([string]$Server, [string]$Domain, [int]$TimeoutSec)
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Resolve-DnsName -Name $Domain -Server $Server -Type A -DnsOnly -ErrorAction Stop
            $sw.Stop()
            return [int]$sw.ElapsedMilliseconds
        } catch { return -1 }
    }

    $ips = @()
    foreach ($ip in $Provider.IPv4) { if ($ip) { $ips += $ip } }
    if ($HasIPv6) {
        foreach ($ip in $Provider.IPv6) { if ($ip) { $ips += $ip } }
    }

    $totalLatency = 0; $resolved = 0; $failed = 0

    if ($ips.Count -eq 0) {
        return @{
            Name = $Provider.Name; AvgMs = 9999; Resolved = 0
            Failed = $Domains.Count; Reliability = 0.0
            IPv4 = ($Provider.IPv4 -join ","); IPv6 = ($Provider.IPv6 -join ",")
        }
    }

    foreach ($domain in $Domains) {
        $best = -1
        foreach ($ip in $ips) {
            for ($q = 0; $q -lt $Queries; $q++) {
                $latency = Test-DnsLatency -Server $ip -Domain $domain -TimeoutSec $Timeout
                if ($latency -ge 0 -and ($best -lt 0 -or $latency -lt $best)) {
                    $best = $latency
                }
            }
        }
        if ($best -ge 0) { $resolved++; $totalLatency += $best }
        else { $failed++ }
    }

    $avgMs = if ($resolved -gt 0) { [int]($totalLatency / $resolved) } else { 9999 }
    $reliability = [math]::Round(($resolved / $Domains.Count) * 100, 1)

    return @{
        Name = $Provider.Name; AvgMs = $avgMs; Resolved = $resolved
        Failed = $failed; Reliability = $reliability
        IPv4 = ($Provider.IPv4 -join ","); IPv6 = ($Provider.IPv6 -join ",")
    }
}

foreach ($provider in $Providers) {
    $ps = [powershell]::Create().AddScript($scriptBlock).AddArgument($provider).AddArgument($Domains).AddArgument($Queries).AddArgument($Timeout).AddArgument($HasIPv6)
    $ps.RunspacePool = $runspacePool
    $runspaces += @{ Pipe = $ps; Status = $ps.BeginInvoke(); Provider = $provider.Name }
}

# Wait for all to complete with progress
while ($runspaces | Where-Object { -not $_.Status.IsCompleted }) {
    $done = ($runspaces | Where-Object { $_.Status.IsCompleted }).Count
    $pct = [int](($done / $providerCount) * 100)
    $barLen = [int]($pct / 2)
    $bar = ([char]0x2588).ToString() * $barLen + ([char]0x2591).ToString() * (50 - $barLen)
    Write-Host -NoNewline "`r  ${GRN}${bar}${RST} ${BLD}$($pct.ToString().PadLeft(3))%${RST}  " -ForegroundColor White
    Start-Sleep -Milliseconds 500
}

foreach ($rs in $runspaces) {
    $result = $rs.Pipe.EndInvoke($rs.Status)
    $results += $result
    $rs.Pipe.Dispose()
}
$runspacePool.Close()

Write-Host "`r  $(([char]0x2588).ToString() * 50) ${BLD}100%${RST}  Complete!          "
Write-Host ""

# Sort results by AvgMs
$results = $results | Sort-Object { $_.AvgMs }

# Find max latency for scaling (excluding 9999)
$maxLat = ($results | Where-Object { $_.AvgMs -lt 9999 } | Measure-Object -Property AvgMs -Maximum).Maximum
if (-not $maxLat -or $maxLat -eq 0) { $maxLat = 1 }

# ── Top Performers ───────────────────────────────────────────────────────────
Write-Host "  ${BLD}${GOLD}$(([char]0x1F3C6)) TOP PERFORMERS${RST}"
Write-Host "  ${DKGRY}$('=' * 60)${RST}"
Write-Host ""

$medals = @("${GOLD}1st", "${SLVR}2nd", "${BRNZ}3rd")
$medalIcons = @("${GOLD}*", "${SLVR}*", "${BRNZ}*")
$limit = [math]::Min(3, $results.Count)

for ($i = 0; $i -lt $limit; $i++) {
    $r = $results[$i]
    $latDisplay = if ($r.AvgMs -ge 9999) { "TIMEOUT" } else { "$($r.AvgMs)ms" }
    Write-Host "    $($medalIcons[$i]) ${BLD}$($medals[$i])${RST}  ${BLD}${WHT}$($r.Name)${RST}"
    $bar = Get-Bar -Value $r.AvgMs -MaxValue $maxLat -Width 30 -Color $GRN
    Write-Host "         ${bar}  ${BLD}${latDisplay}${RST}  ${GRY}($($r.Reliability)% reliable)${RST}"
    Write-Host ""
}

# ── DNS Configuration ────────────────────────────────────────────────────────
Write-Host "  ${BLD}${CYN}DNS CONFIGURATION - Enter these addresses in your network settings${RST}"
Write-Host "  ${DKGRY}$('=' * 68)${RST}"
Write-Host ""

for ($i = 0; $i -lt $limit; $i++) {
    $r = $results[$i]
    if ($r.AvgMs -ge 9999) { continue }
    Write-Host "    $($medalIcons[$i]) ${BLD}$($medals[$i])${RST}  ${BLD}${WHT}$($r.Name)${RST}"
    if ($r.IPv4) {
        $ipv4Display = $r.IPv4 -replace ",", "  |  "
        Write-Host "         ${GRY}IPv4:${RST}  ${BLD}${WHT}${ipv4Display}${RST}"
    }
    if ($r.IPv6) {
        $ipv6Display = $r.IPv6 -replace ",", "  |  "
        Write-Host "         ${GRY}IPv6:${RST}  ${BLD}${WHT}${ipv6Display}${RST}"
    }
    Write-Host ""
}

# ── Full Rankings ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ${BLD}${CYN}> FULL RANKINGS${RST}"
Write-Host "  ${DKGRY}$('=' * 80)${RST}"
Write-Host ("  ${BLD}${GRY}{0,-4} {1,-22} {2,8}  {3,-25} {4,8}${RST}" -f "#", "Provider", "Avg ms", "Latency", "Reliab.")
Write-Host "  ${DKGRY}$('-' * 80)${RST}"

for ($i = 0; $i -lt $results.Count; $i++) {
    $rank = $i + 1
    $r = $results[$i]
    $latDisplay = if ($r.AvgMs -ge 9999) { "TIMEOUT" } else { "$($r.AvgMs)ms" }

    # Color based on latency
    $barColor = if ($r.AvgMs -lt 20) { $GRN }
                elseif ($r.AvgMs -lt 50) { $CYN }
                elseif ($r.AvgMs -lt 100) { $YLW }
                elseif ($r.AvgMs -lt 200) { $ORG }
                else { $RED }

    $relColor = if ($r.Reliability -ge 100) { $GRN }
                elseif ($r.Reliability -ge 80) { $YLW }
                else { $RED }

    $rankColor = if ($rank -le 3) { $WHT } else { $GRY }

    $bar = ""
    if ($r.AvgMs -lt 9999) {
        $bar = Get-Bar -Value $r.AvgMs -MaxValue $maxLat -Width 25 -Color $barColor
    } else {
        $bar = "${RED}  -- no response --${RST}"
    }

    Write-Host -NoNewline ("  ${rankColor}${BLD}{0,3}${RST} " -f $rank)
    Write-Host -NoNewline ("${barColor}{0,-22}${RST} " -f ($r.Name.Substring(0, [math]::Min($r.Name.Length, 22))))
    Write-Host -NoNewline ("${BLD}{0,6}${RST}  " -f $latDisplay)
    Write-Host -NoNewline $bar
    Write-Host (" ${relColor}{0,6}%${RST}" -f $r.Reliability)
}

Write-Host "  ${DKGRY}$('=' * 80)${RST}"
Write-Host ""

# ── Latency Distribution ─────────────────────────────────────────────────────
Write-Host "  ${BLD}${MAG}* LATENCY DISTRIBUTION${RST}"
Write-Host "  ${DKGRY}$('=' * 60)${RST}"

$buckets = @(0, 0, 0, 0, 0)
$bucketLabels = @("<20ms", "20-50ms", "50-100ms", "100-200ms", "200ms+")
$bucketColors = @($GRN, $CYN, $YLW, $ORG, $RED)

foreach ($r in $results) {
    if ($r.AvgMs -lt 20) { $buckets[0]++ }
    elseif ($r.AvgMs -lt 50) { $buckets[1]++ }
    elseif ($r.AvgMs -lt 100) { $buckets[2]++ }
    elseif ($r.AvgMs -lt 200) { $buckets[3]++ }
    else { $buckets[4]++ }
}

for ($b = 0; $b -lt 5; $b++) {
    $bar = Get-Bar -Value $buckets[$b] -MaxValue $results.Count -Width 30 -Color $bucketColors[$b]
    Write-Host ("    ${GRY}{0,-10}${RST} {1} ${BLD}{2}${RST}" -f $bucketLabels[$b], $bar, $buckets[$b])
}
Write-Host ""

# ── Export CSV ────────────────────────────────────────────────────────────────
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvFile = "dns-bench-${timestamp}.csv"
$csvContent = @("rank,provider,avg_latency_ms,domains_resolved,domains_failed,reliability_pct,ipv4_servers,ipv6_servers")
$rank = 0
foreach ($r in $results) {
    $rank++
    $csvContent += "$rank,`"$($r.Name)`",$($r.AvgMs),$($r.Resolved),$($r.Failed),$($r.Reliability),`"$($r.IPv4)`",`"$($r.IPv6)`""
}
$csvContent | Out-File -FilePath $csvFile -Encoding UTF8
Write-Host "  ${GRY}* Results saved to ${BLD}${csvFile}${RST}"
Write-Host ""
Write-Host "  ${DIM}${GRY}github.com/GodSpoon/dns-bench${RST}"
Write-Host ""
