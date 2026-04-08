# dns-bench

Fast DNS provider benchmarking from your terminal. Like [Ookla Speedtest](https://www.speedtest.net/apps/cli), but for DNS.

![Bash](https://img.shields.io/badge/bash-4.3+-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue) ![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

## Quick Start

**macOS / Linux:**

```sh
curl -sSL https://raw.githubusercontent.com/GodSpoon/dns-bench/main/dns-bench.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/GodSpoon/dns-bench/main/dns-bench.ps1 -OutFile dns-bench.ps1; .\dns-bench.ps1
```

## What It Does

Benchmarks **72 public DNS providers** (from the [AdGuard Known DNS Providers](https://adguard-dns.io/kb/general/dns-providers/) list) across **20 popular domains**, measuring latency and reliability — then ranks them with a colorized terminal UI featuring bar graphs, a podium for top performers, and **DNS server addresses you should configure** for the best results.

- **IPv4 & IPv6**: Automatically detects IPv6 connectivity and benchmarks both protocols
- **DNS Configuration**: Shows the exact IPv4/IPv6 addresses to enter in your network settings for each top performer
- **Category Filtering**: Choose which types of DNS providers to benchmark (or test all)
- **Cross-platform**: Works on macOS, Linux, and Windows (PowerShell)

## Provider Categories

An interactive menu lets you pick one or more categories before benchmarking. Default is **all**.

| # | Category | Description |
|---|----------|-------------|
| 1 | **Privacy-Focused / No-Log** | Minimal or zero query logging — DNS.SB, Mullvad, DNS.WATCH, CIRA Private, Freenom World, and more |
| 2 | **General Purpose (Unfiltered)** | Fast, reliable, no content blocking — Google, Cloudflare, Yandex Basic, AliDNS, DNSPod, Level3, Dyn, and more |
| 3 | **Security / Malware Blocking** | Blocks malicious domains & phishing — Quad9, Cloudflare Malware, OpenDNS, Comodo Secure, ControlD, CleanBrowsing Security, and more |
| 4 | **Ad & Tracker Blocking** | Strips ads and trackers — AdGuard Default, AhaDNS, OSZX, DNS Forge, Comss.ru, and more |
| 5 | **Family / Content Filtering** | Blocks adult content & more — AdGuard Family, OpenDNS FamilyShield, CleanBrowsing Family, Cloudflare Family, and more |

You can also skip the menu with CLI flags:

```sh
# Test all providers (skip menu)
bash dns-bench.sh --all

# Test only privacy-focused resolvers
bash dns-bench.sh --category privacy

# Test security + ad-blocking providers
bash dns-bench.sh --category security,adblock
```

## Options

### Bash (macOS / Linux)

```
-q, --queries N      Queries per domain per server (default: 3)
-d, --domains FILE   Custom domains file (one per line)
-t, --timeout N      Query timeout in seconds (default: 2)
-j, --jobs N         Parallel jobs (default: 10)
-c, --category LIST  Comma-separated category filter (default: interactive menu)
                     Categories: privacy, general, security, adblock, family
-a, --all            Benchmark all providers, skip category menu
    --no-color       Disable colored output
-h, --help           Show help
```

### PowerShell (Windows)

```
-Queries N           Queries per domain per server (default: 3)
-Timeout N           Query timeout in seconds (default: 2)
-Jobs N              Parallel jobs (default: 10)
-Category LIST       Comma-separated category filter (default: interactive menu)
                     Categories: privacy, general, security, adblock, family
-All                 Benchmark all providers, skip category menu
-NoColor             Disable colored output
-Help                Show help
```

**Examples:**

```sh
# Run with interactive category menu (default)
bash dns-bench.sh

# Benchmark all providers
bash dns-bench.sh --all

# Only privacy-focused resolvers
bash dns-bench.sh --category privacy

# More thorough test, family category only
bash dns-bench.sh -q 5 -t 3 --category family

# Custom domains
bash dns-bench.sh -d my-domains.txt

# Windows PowerShell — all providers
.\dns-bench.ps1 -All

# Windows PowerShell — security category
.\dns-bench.ps1 -Category security
```

## Requirements

### macOS / Linux
- **bash** 4.3+
- **dig** (auto-installed if missing)
- **bc**, **awk**, **sort** (standard on most systems)

Dependencies are auto-installed on macOS (via Homebrew) and Linux (via apt/dnf/yum/pacman/apk/zypper).

### Windows
- **PowerShell** 5.1+ (included with Windows 10/11)
- **Resolve-DnsName** cmdlet (included with Windows)

## Output

- **Terminal:** Ranked table with latency bars, top-3 podium, DNS configuration for top performers, and latency distribution chart
- **CSV:** Results exported to `dns-bench-YYYYMMDD-HHMMSS.csv` in the current directory

## License

MIT
