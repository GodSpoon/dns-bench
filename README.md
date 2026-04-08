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
- **Cross-platform**: Works on macOS, Linux, and Windows (PowerShell)

**Tested providers include:** AdGuard, Cloudflare, Google, Quad9, OpenDNS, NextDNS, CleanBrowsing, Neustar, Verisign, Yandex, CIRA, CZ.NIC, AliDNS, DNS.SB, DNS Forge, and [many more](https://adguard-dns.io/kb/general/dns-providers/).

## Options

### Bash (macOS / Linux)

```
-q, --queries N      Queries per domain per server (default: 3)
-d, --domains FILE   Custom domains file (one per line)
-t, --timeout N      Query timeout in seconds (default: 2)
-j, --jobs N         Parallel jobs (default: 10)
    --no-color       Disable colored output
-h, --help           Show help
```

### PowerShell (Windows)

```
-Queries N           Queries per domain per server (default: 3)
-Timeout N           Query timeout in seconds (default: 2)
-Jobs N              Parallel jobs (default: 10)
-NoColor             Disable colored output
-Help                Show help
```

**Examples:**

```sh
# Run with defaults
bash dns-bench.sh

# More thorough test
bash dns-bench.sh -q 5 -t 3

# Custom domains
bash dns-bench.sh -d my-domains.txt

# Windows PowerShell
.\dns-bench.ps1 -Queries 5 -Timeout 3
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
