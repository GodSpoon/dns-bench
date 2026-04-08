# dns-bench

Fast DNS provider benchmarking from your terminal. Like [Ookla Speedtest](https://www.speedtest.net/apps/cli), but for DNS.

![Bash](https://img.shields.io/badge/bash-5.0+-blue) ![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

## Quick Start

```sh
curl -sSL https://raw.githubusercontent.com/GodSpoon/dns-bench/main/dns-bench.sh -o dns-bench.sh
bash dns-bench.sh
```

## What It Does

Benchmarks **20 public DNS providers** across **20 popular domains**, measuring latency and reliability — then ranks them with a colorized terminal UI featuring bar graphs and a podium for top performers.

**Tested providers include:** Cloudflare, Google, Quad9, OpenDNS, NextDNS, AdGuard, and more.

## Options

```
-q, --queries N      Queries per domain per server (default: 3)
-d, --domains FILE   Custom domains file (one per line)
-t, --timeout N      Query timeout in seconds (default: 2)
-j, --jobs N         Parallel jobs (default: 10)
    --no-color       Disable colored output
-h, --help           Show help
```

**Examples:**

```sh
# Run with defaults
bash dns-bench.sh

# More thorough test
bash dns-bench.sh -q 5 -t 3

# Custom domains
bash dns-bench.sh -d my-domains.txt
```

## Requirements

- **bash** 4.3+
- **dig** (auto-installed if missing)
- **bc**, **awk**, **sort** (standard on most systems)

Dependencies are auto-installed on macOS (via Homebrew) and Linux (via apt/dnf/yum/pacman/apk/zypper).

## Output

- **Terminal:** Ranked table with latency bars, top-3 podium, and latency distribution chart
- **CSV:** Results exported to `dns-bench-YYYYMMDD-HHMMSS.csv` in the current directory

## License

MIT
