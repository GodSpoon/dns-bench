#!/usr/bin/env bash
# dns-bench — DNS Provider Performance Benchmark
# A speedtest-style CLI for DNS provider benchmarking
# https://github.com/GodSpoon/dns-bench
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/GodSpoon/dns-bench/main/dns-bench.sh -o dns-bench.sh && bash dns-bench.sh
#   bash dns-bench.sh [--queries N] [--domains FILE] [--timeout N] [--jobs N] [--no-color] [--help]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
QUERIES=3
DOMAINS_FILE=""
TIMEOUT=2
MAX_JOBS=10
COLOR=true
VERSION="1.0.0"

# ── Parse Arguments ───────────────────────────────────────────────────────────
usage() {
  cat <<'USAGE'
dns-bench — DNS Provider Performance Benchmark

Usage:
  dns-bench.sh [OPTIONS]

Options:
  -q, --queries N      Queries per domain per server (default: 3)
  -d, --domains FILE   Custom domains file (one per line)
  -t, --timeout N      Query timeout in seconds (default: 2)
  -j, --jobs N         Parallel jobs (default: 10)
      --no-color       Disable colored output
  -h, --help           Show this help
  -v, --version        Show version
USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--queries)  QUERIES="$2"; shift 2 ;;
    -d|--domains)  DOMAINS_FILE="$2"; shift 2 ;;
    -t|--timeout)  TIMEOUT="$2"; shift 2 ;;
    -j|--jobs)     MAX_JOBS="$2"; shift 2 ;;
    --no-color)    COLOR=false; shift ;;
    -h|--help)     usage ;;
    -v|--version)  echo "dns-bench $VERSION"; exit 0 ;;
    *)             echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ── Colors & Symbols ──────────────────────────────────────────────────────────
if $COLOR && [[ -t 1 ]]; then
  RST='\033[0m'
  BLD='\033[1m'
  DIM='\033[2m'
  UND='\033[4m'
  RED='\033[38;5;196m'
  GRN='\033[38;5;46m'
  YLW='\033[38;5;226m'
  BLU='\033[38;5;33m'
  CYN='\033[38;5;51m'
  MAG='\033[38;5;165m'
  ORG='\033[38;5;208m'
  WHT='\033[38;5;255m'
  GRY='\033[38;5;244m'
  DKGRY='\033[38;5;238m'
  GOLD='\033[38;5;220m'
  SLVR='\033[38;5;250m'
  BRNZ='\033[38;5;180m'
  BG_GRN='\033[48;5;22m'
  BG_RED='\033[48;5;52m'
  BG_BLU='\033[48;5;17m'
else
  RST='' BLD='' DIM='' UND='' RED='' GRN='' YLW='' BLU='' CYN='' MAG=''
  ORG='' WHT='' GRY='' DKGRY='' GOLD='' SLVR='' BRNZ=''
  BG_GRN='' BG_RED='' BG_BLU=''
fi

BAR_FULL="█"
BAR_7="▉"
BAR_6="▊"
BAR_5="▋"
BAR_4="▌"
BAR_3="▍"
BAR_2="▎"
BAR_1="▏"
ARROW="▶"
CHECK="✔"
CROSS="✖"
DIAMOND="◆"
CIRCLE="●"
TROPHY="🏆"

# ── Temp Directory ────────────────────────────────────────────────────────────
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
banner() {
  echo
  echo -e "${CYN}${BLD}    ╔══════════════════════════════════════════════════╗${RST}"
  echo -e "${CYN}${BLD}    ║${RST}${WHT}${BLD}      ┏━┓ ┏┓╻ ┏━┓   ┏┓  ┏━╸ ┏┓╻ ┏━╸ ╻ ╻       ${RST}${CYN}${BLD}║${RST}"
  echo -e "${CYN}${BLD}    ║${RST}${WHT}${BLD}      ┃ ┃ ┃┗┫ ┗━┓   ┣┻┓ ┣╸  ┃┗┫ ┃   ┣━┫       ${RST}${CYN}${BLD}║${RST}"
  echo -e "${CYN}${BLD}    ║${RST}${WHT}${BLD}      ┗━┛ ╹ ╹ ┗━┛   ┗━┛ ┗━╸ ╹ ╹ ┗━╸ ╹ ╹       ${RST}${CYN}${BLD}║${RST}"
  echo -e "${CYN}${BLD}    ║${RST}${GRY}           DNS Provider Benchmark v${VERSION}          ${RST}${CYN}${BLD}║${RST}"
  echo -e "${CYN}${BLD}    ╚══════════════════════════════════════════════════╝${RST}"
  echo
}

# ── Dependency Check & Auto-Install ──────────────────────────────────────────
detect_os() {
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
    *)       OS="unknown" ;;
  esac
}

install_deps() {
  local missing=()
  for cmd in dig bc awk sort; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  echo -e "${YLW}${BLD}${ARROW} Missing dependencies: ${missing[*]}${RST}"

  detect_os

  case "$OS" in
    macos)
      echo -e "${DIM}  Installing via Homebrew...${RST}"
      if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}${CROSS} Homebrew not found. Install from https://brew.sh${RST}" >&2
        exit 1
      fi
      for cmd in "${missing[@]}"; do
        case "$cmd" in
          dig) brew install --quiet bind 2>/dev/null || true ;;
          bc)  brew install --quiet bc 2>/dev/null || true ;;
          *)   ;; # awk and sort are typically pre-installed on macOS
        esac
      done
      ;;
    linux)
      echo -e "${DIM}  Installing via package manager...${RST}"
      local pkg_install=""
      if command -v apt-get >/dev/null 2>&1; then
        pkg_install="sudo apt-get install -y -qq"
      elif command -v dnf >/dev/null 2>&1; then
        pkg_install="sudo dnf install -y -q"
      elif command -v yum >/dev/null 2>&1; then
        pkg_install="sudo yum install -y -q"
      elif command -v pacman >/dev/null 2>&1; then
        pkg_install="sudo pacman -S --noconfirm --quiet"
      elif command -v apk >/dev/null 2>&1; then
        pkg_install="sudo apk add --quiet"
      elif command -v zypper >/dev/null 2>&1; then
        pkg_install="sudo zypper install -y --quiet"
      fi

      if [[ -z "$pkg_install" ]]; then
        echo -e "${RED}${CROSS} No supported package manager found.${RST}" >&2
        echo -e "${RED}  Please install manually: ${missing[*]}${RST}" >&2
        exit 1
      fi

      for cmd in "${missing[@]}"; do
        case "$cmd" in
          dig)
            if [[ "$pkg_install" == *apk* ]]; then
              $pkg_install bind-tools 2>/dev/null || true
            else
              $pkg_install dnsutils 2>/dev/null || $pkg_install bind-utils 2>/dev/null || true
            fi
            ;;
          bc)  $pkg_install bc 2>/dev/null || true ;;
          *)   ;; # awk and sort are typically pre-installed
        esac
      done
      ;;
    *)
      echo -e "${RED}${CROSS} Unsupported OS. Please install: ${missing[*]}${RST}" >&2
      exit 1
      ;;
  esac

  # Verify all installed
  for cmd in "${missing[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo -e "${RED}${CROSS} Failed to install: $cmd${RST}" >&2
      exit 1
    fi
  done
  echo -e "${GRN}${CHECK} Dependencies installed${RST}"
}

# ── Domains ───────────────────────────────────────────────────────────────────
DEFAULT_DOMAINS=(
  google.com
  youtube.com
  facebook.com
  amazon.com
  wikipedia.org
  reddit.com
  netflix.com
  linkedin.com
  apple.com
  microsoft.com
  github.com
  twitter.com
  instagram.com
  tiktok.com
  ebay.com
  paypal.com
  yahoo.com
  cnn.com
  nytimes.com
  cloudflare.com
)

if [[ -n "$DOMAINS_FILE" ]]; then
  if [[ ! -f "$DOMAINS_FILE" ]]; then
    echo -e "${RED}${CROSS} Domains file not found: $DOMAINS_FILE${RST}" >&2
    exit 1
  fi
  mapfile -t DOMAINS < <(grep -vE '^\s*($|#)' "$DOMAINS_FILE" | awk '{print $1}')
else
  DOMAINS=("${DEFAULT_DOMAINS[@]}")
fi

# ── DNS Providers ─────────────────────────────────────────────────────────────
# Format: "Name|IP1,IP2"
declare -a PROVIDERS=(
  # Major public resolvers
  "Cloudflare|1.1.1.1,1.0.0.1"
  "Google|8.8.8.8,8.8.4.4"
  "Quad9|9.9.9.9,149.112.112.112"
  "OpenDNS|208.67.222.222,208.67.220.220"
  "NextDNS|45.90.28.0,45.90.30.0"
  "AdGuard|94.140.14.14,94.140.15.15"
  "CleanBrowsing|185.228.168.9,185.228.169.9"
  "Comodo Secure|8.26.56.26,8.20.247.20"
  "ControlD|76.76.2.0,76.76.10.0"
  "Level3|4.2.2.1,4.2.2.2"
  "Verisign|64.6.64.6,64.6.65.6"
  "DNS.Watch|84.200.69.80,84.200.70.40"
  "Yandex|77.88.8.8,77.88.8.1"
  "Neustar|156.154.70.5,156.154.71.5"
  "SafeDNS|195.46.39.39,195.46.39.40"
  "LibreDNS|116.202.176.26"
  "Freenom|80.80.80.80,80.80.81.81"
  "AliDNS|223.5.5.5,223.6.6.6"
  "Mullvad|194.242.2.2"
  "DNS0.eu|193.110.81.0,185.253.5.0"
)

PROVIDER_COUNT=${#PROVIDERS[@]}

# ── Core Benchmark ────────────────────────────────────────────────────────────

# Query a single domain against a single IP, return avg latency in ms or "FAIL"
query_domain() {
  local ip="$1" domain="$2" runs="$3"
  local total=0 success=0 t
  for _ in $(seq 1 "$runs"); do
    t=$(dig +time="$TIMEOUT" +tries=1 +noall +stats "@$ip" "$domain" A 2>/dev/null \
      | awk '/Query time:/{print $4}')
    if [[ -n "$t" ]]; then
      success=$((success + 1))
      total=$((total + t))
    fi
  done
  if (( success > 0 )); then
    echo "$((total / success))"
  else
    echo "FAIL"
  fi
}

# Benchmark a single provider (all domains), write result to file
bench_provider() {
  local idx="$1" entry="$2" result_file="$3"
  IFS='|' read -r name ips_csv <<< "$entry"
  IFS=',' read -r -a ips <<< "$ips_csv"

  local total_latency=0 resolved=0 failed=0

  for domain in "${DOMAINS[@]}"; do
    local best=""
    for ip in "${ips[@]}"; do
      local result
      result=$(query_domain "$ip" "$domain" "$QUERIES")
      if [[ "$result" != "FAIL" ]]; then
        if [[ -z "$best" ]] || (( result < best )); then
          best="$result"
        fi
      fi
    done
    if [[ -n "$best" ]]; then
      resolved=$((resolved + 1))
      total_latency=$((total_latency + best))
    else
      failed=$((failed + 1))
    fi
  done

  local avg_ms="9999" reliability="0"
  if (( resolved > 0 )); then
    avg_ms=$((total_latency / resolved))
  fi
  reliability=$(awk -v r="$resolved" -v t="${#DOMAINS[@]}" 'BEGIN { printf "%.1f", (r/t)*100 }')

  # Write each provider to its own file to avoid race conditions
  echo "${idx}|${name}|${avg_ms}|${resolved}|${failed}|${reliability}" > "${result_file}.${idx}"
}

# ── Progress Display ──────────────────────────────────────────────────────────
show_progress() {
  local current="$1" total="$2" name="$3"
  local pct=$((current * 100 / total))
  local filled=$((pct / 2))
  local empty=$((50 - filled))
  local bar=""
  local j

  # Gradient bar
  for ((j = 0; j < filled; j++)); do
    if (( j < 17 )); then
      bar+="${GRN}${BAR_FULL}"
    elif (( j < 34 )); then
      bar+="${CYN}${BAR_FULL}"
    else
      bar+="${BLU}${BAR_FULL}"
    fi
  done
  for ((j = 0; j < empty; j++)); do
    bar+="${DKGRY}${BAR_1}"
  done

  printf "\r  ${bar}${RST} ${BLD}%3d%%${RST}  ${GRY}%-20.20s${RST}" "$pct" "$name"
}

# ── Run Benchmark ─────────────────────────────────────────────────────────────
run_benchmark() {
  local results_file="$WORK/results.txt"
  local progress_file="$WORK/progress"
  > "$results_file"
  echo "0" > "$progress_file"

  echo -e "  ${GRY}Testing ${BLD}${WHT}${PROVIDER_COUNT}${RST}${GRY} providers across ${BLD}${WHT}${#DOMAINS[@]}${RST}${GRY} domains (${QUERIES} queries each)${RST}"
  echo -e "  ${GRY}Timeout: ${TIMEOUT}s | Parallel jobs: ${MAX_JOBS}${RST}"
  echo

  local running=0 idx=0

  for entry in "${PROVIDERS[@]}"; do
    idx=$((idx + 1))
    IFS='|' read -r name _ <<< "$entry"
    show_progress "$idx" "$PROVIDER_COUNT" "$name"

    bench_provider "$idx" "$entry" "$results_file" &
    running=$((running + 1))

    if (( running >= MAX_JOBS )); then
      # wait -n (bash 4.3+) waits for any single job; fallback waits for all
      if ! wait -n 2>/dev/null; then
        wait
        running=0
      else
        running=$((running - 1))
      fi
    fi
  done
  wait

  show_progress "$PROVIDER_COUNT" "$PROVIDER_COUNT" "Complete!"
  echo
  echo

  # Merge per-provider result files
  for i in $(seq 1 "$PROVIDER_COUNT"); do
    cat "${results_file}.${i}" >> "$results_file" 2>/dev/null || true
  done
}

# ── Render Bar Graph ──────────────────────────────────────────────────────────
render_bar() {
  local value="$1" max_value="$2" width="$3" color="$4"
  if (( max_value == 0 )); then max_value=1; fi

  local scaled
  scaled=$(awk -v v="$value" -v m="$max_value" -v w="$width" 'BEGIN {
    s = (v / m) * w * 8
    if (s < 1 && v > 0) s = 1
    printf "%d", s
  }')

  local full_blocks=$((scaled / 8))
  local remainder=$((scaled % 8))
  local bar=""
  local subs=("" "$BAR_1" "$BAR_2" "$BAR_3" "$BAR_4" "$BAR_5" "$BAR_6" "$BAR_7")

  local j
  for ((j = 0; j < full_blocks; j++)); do
    bar+="${BAR_FULL}"
  done
  if (( remainder > 0 )); then
    bar+="${subs[$remainder]}"
  fi

  echo -ne "${color}${bar}${RST}"
}

# ── Display Results ───────────────────────────────────────────────────────────
display_results() {
  local results_file="$WORK/results.txt"
  local sorted_file="$WORK/sorted.txt"

  # Sort by avg_ms (field 3) ascending, treating 9999 as worst
  sort -t'|' -k3,3n "$results_file" > "$sorted_file"

  local count
  count=$(wc -l < "$sorted_file")

  # Read results into arrays
  local -a names=() latencies=() resolved=() failed=() reliabilities=()
  while IFS='|' read -r _idx name avg res fail rel; do
    names+=("$name")
    latencies+=("$avg")
    resolved+=("$res")
    failed+=("$fail")
    reliabilities+=("$rel")
  done < "$sorted_file"

  # Find max latency for graph scaling (excluding 9999)
  local max_lat=1
  for lat in "${latencies[@]}"; do
    if (( lat < 9999 && lat > max_lat )); then
      max_lat=$lat
    fi
  done

  # ── Top 3 Podium ────────────────────────────────────────────────────────
  echo -e "  ${BLD}${GOLD}${TROPHY} TOP PERFORMERS${RST}"
  echo -e "  ${DKGRY}$(printf '━%.0s' {1..60})${RST}"
  echo

  local medals=("${GOLD}1st" "${SLVR}2nd" "${BRNZ}3rd")
  local medal_icons=("${GOLD}${DIAMOND}" "${SLVR}${DIAMOND}" "${BRNZ}${DIAMOND}")
  local limit=3
  if (( count < limit )); then limit=$count; fi

  for ((i = 0; i < limit; i++)); do
    local lat="${latencies[$i]}"
    local lat_display="${lat}ms"
    if (( lat >= 9999 )); then lat_display="TIMEOUT"; fi
    echo -e "    ${medal_icons[$i]} ${BLD}${medals[$i]}${RST}  ${BLD}${WHT}${names[$i]}${RST}"
    echo -ne "         "
    render_bar "$lat" "$max_lat" 30 "${GRN}"
    echo -e "  ${BLD}${lat_display}${RST}  ${GRY}(${reliabilities[$i]}% reliable)${RST}"
    echo
  done

  # ── Full Rankings Table ─────────────────────────────────────────────────
  echo
  echo -e "  ${BLD}${CYN}${ARROW} FULL RANKINGS${RST}"
  echo -e "  ${DKGRY}$(printf '━%.0s' {1..76})${RST}"
  printf "  ${BLD}${GRY}%-4s %-18s %8s  %-25s %8s${RST}\n" "#" "Provider" "Avg ms" "Latency" "Reliab."
  echo -e "  ${DKGRY}$(printf '─%.0s' {1..76})${RST}"

  for ((i = 0; i < count; i++)); do
    local rank=$((i + 1))
    local lat="${latencies[$i]}"
    local rel="${reliabilities[$i]}"
    local lat_display="${lat}ms"
    local bar_color

    # Color tier based on latency
    if (( lat < 20 )); then
      bar_color="$GRN"
    elif (( lat < 50 )); then
      bar_color="$CYN"
    elif (( lat < 100 )); then
      bar_color="$YLW"
    elif (( lat < 200 )); then
      bar_color="$ORG"
    elif (( lat >= 9999 )); then
      bar_color="$RED"
      lat_display="TIMEOUT"
    else
      bar_color="$RED"
    fi

    # Reliability indicator
    local rel_color="$GRN"
    local rel_num
    rel_num=$(echo "$rel" | cut -d. -f1)
    if (( rel_num < 100 )); then rel_color="$YLW"; fi
    if (( rel_num < 80 )); then rel_color="$RED"; fi

    local rank_color="$GRY"
    if (( rank <= 3 )); then rank_color="$WHT"; fi

    printf "  ${rank_color}${BLD}%3d${RST} " "$rank"
    printf "${bar_color}%-18.18s${RST} " "${names[$i]}"
    printf "${BLD}%6s${RST}  " "$lat_display"

    # Inline latency bar
    if (( lat < 9999 )); then
      render_bar "$lat" "$max_lat" 25 "$bar_color"
      # Pad remaining space
      local bar_chars
      bar_chars=$(awk -v v="$lat" -v m="$max_lat" -v w="25" 'BEGIN {
        s = (v / m) * w
        if (s < 1 && v > 0) s = 1
        printf "%d", int(s) + 1
      }')
      local pad=$((25 - bar_chars))
      if (( pad > 0 )); then printf "%*s" "$pad" ""; fi
    else
      printf "${RED}%-25s${RST}" "  ── no response ──"
    fi

    printf " ${rel_color}%6s%%${RST}" "$rel"
    echo
  done

  echo -e "  ${DKGRY}$(printf '━%.0s' {1..76})${RST}"
  echo

  # ── Latency Distribution Graph ─────────────────────────────────────────
  echo -e "  ${BLD}${MAG}${CIRCLE} LATENCY DISTRIBUTION${RST}"
  echo -e "  ${DKGRY}$(printf '━%.0s' {1..60})${RST}"

  local buckets=(0 0 0 0 0)
  local bucket_labels=("<20ms" "20-50ms" "50-100ms" "100-200ms" "200ms+")
  local bucket_colors=("$GRN" "$CYN" "$YLW" "$ORG" "$RED")

  for lat in "${latencies[@]}"; do
    if (( lat < 20 )); then
      buckets[0]=$((buckets[0] + 1))
    elif (( lat < 50 )); then
      buckets[1]=$((buckets[1] + 1))
    elif (( lat < 100 )); then
      buckets[2]=$((buckets[2] + 1))
    elif (( lat < 200 )); then
      buckets[3]=$((buckets[3] + 1))
    else
      buckets[4]=$((buckets[4] + 1))
    fi
  done

  for ((b = 0; b < 5; b++)); do
    printf "    ${GRY}%-10s${RST} " "${bucket_labels[$b]}"
    render_bar "${buckets[$b]}" "$count" 30 "${bucket_colors[$b]}"
    echo -e " ${BLD}${buckets[$b]}${RST}"
  done
  echo
}

# ── Export Results ────────────────────────────────────────────────────────────
export_results() {
  local sorted_file="$WORK/sorted.txt"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local csv_file="dns-bench-${timestamp}.csv"

  {
    echo "rank,provider,avg_latency_ms,domains_resolved,domains_failed,reliability_pct"
    local rank=0
    while IFS='|' read -r _idx name avg res fail rel; do
      rank=$((rank + 1))
      echo "${rank},\"${name}\",${avg},${res},${fail},${rel}"
    done < "$sorted_file"
  } > "$csv_file"

  echo -e "  ${GRY}${CHECK} Results saved to ${BLD}${csv_file}${RST}"
}

# ── System Info ───────────────────────────────────────────────────────────────
show_system_info() {
  detect_os
  local os_name
  case "$OS" in
    macos) os_name="macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')" ;;
    linux) os_name="Linux $(uname -r)" ;;
    *)     os_name="Unknown ($(uname -s))" ;;
  esac

  # Try to detect current DNS server
  local current_dns="unknown"
  if [[ -f /etc/resolv.conf ]]; then
    current_dns=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null || echo "unknown")
  elif command -v scutil >/dev/null 2>&1; then
    current_dns=$(scutil --dns 2>/dev/null | awk '/nameserver\[0\]/{print $3; exit}' || echo "unknown")
  fi

  echo -e "  ${GRY}${CIRCLE} System: ${WHT}${os_name}${RST}"
  echo -e "  ${GRY}${CIRCLE} Current DNS: ${WHT}${current_dns}${RST}"
  echo -e "  ${GRY}${CIRCLE} Date: ${WHT}$(date '+%Y-%m-%d %H:%M:%S %Z')${RST}"
  echo
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  banner
  install_deps
  show_system_info
  run_benchmark
  display_results
  export_results
  echo
  echo -e "  ${DIM}${GRY}github.com/GodSpoon/dns-bench${RST}"
  echo
}

main
