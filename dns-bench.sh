#!/usr/bin/env bash
# Multi-domain DNS benchmark with provider net scoring
# Requires: dig, bc, awk, sort
# Usage:
#   bash dns-benchmark.sh
#   bash dns-benchmark.sh 3
#   bash dns-benchmark.sh 3 domains.txt

set -euo pipefail

QUERIES_PER_DOMAIN="${1:-2}"
DOMAINS_FILE="${2:-}"
TIMEOUT=3
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

RED='\033[0;31m'; YLW='\033[0;33m'; GRN='\033[0;32m'; CYN='\033[0;36m'; BLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'

DEFAULT_DOMAINS=(
  www.google.com
  www.youtube.com
  www.facebook.com
  www.amazon.com
  www.wikipedia.org
  www.reddit.com
  www.netflix.com
  www.linkedin.com
  www.apple.com
  www.microsoft.com
  www.office.com
  www.twitter.com
  www.instagram.com
  www.tiktok.com
  www.ebay.com
  www.paypal.com
  www.yahoo.com
  www.cnn.com
  www.nytimes.com
  www.github.com
)

if [[ -n "$DOMAINS_FILE" ]]; then
  mapfile -t DOMAINS < <(grep -vE '^\s*($|#)' "$DOMAINS_FILE" | awk '{print $1}')
else
  DOMAINS=("${DEFAULT_DOMAINS[@]}")
fi

# Provider list based on IPv4 entries from the AdGuard Known DNS Providers page.
# Each entry: "Provider Family|Variant|ip1,ip2"
declare -a PROVIDERS=(
  "AdGuard DNS|Default|94.140.14.14,94.140.15.15"
  "AdGuard DNS|Family Protection|94.140.14.15,94.140.15.16"
  "AdGuard DNS|Non-filtering|94.140.14.140,94.140.14.141"
  "Ali DNS|Default|223.5.5.5,223.6.6.6"
  "Caliph DNS|Default|160.19.167.150"
  "Cisco OpenDNS|Standard|208.67.222.222,208.67.220.220"
  "Cisco OpenDNS|FamilyShield|208.67.222.123,208.67.220.123"
  "Cisco OpenDNS|Sandbox|208.67.222.2,208.67.220.2"
  "CleanBrowsing|Family Filter|185.228.168.168,185.228.169.168"
  "CleanBrowsing|Adult Filter|185.228.168.10,185.228.169.11"
  "CleanBrowsing|Security Filter|185.228.168.9,185.228.169.9"
  "Cloudflare DNS|Standard|1.1.1.1,1.0.0.1"
  "Cloudflare DNS|Malware Blocking|1.1.1.2,1.0.0.2"
  "Cloudflare DNS|Malware+Adult|1.1.1.3,1.0.0.3"
  "Comodo Secure DNS|Default|8.26.56.26,8.20.247.20"
  "ControlD|Non-filtering|76.76.2.0,76.76.10.0"
  "ControlD|Block Malware|76.76.2.1"
  "ControlD|Block Malware+Ads|76.76.2.2"
  "ControlD|Block Malware+Ads+Social|76.76.2.3"
)

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}Missing dependency: $1${RST}" >&2; exit 1; }; }
need dig; need bc; need awk; need sort

probe_server() {
  local ip="$1" domain="$2" runs="$3"
  local ok=0 fail=0 sum=0 min=999999 max=0
  local t
  for _ in $(seq 1 "$runs"); do
    t=$(dig +time="$TIMEOUT" +tries=1 +noall +stats @"$ip" "$domain" A 2>/dev/null | awk '/Query time:/{print $4}')
    if [[ -n "$t" ]]; then
      ok=$((ok+1))
      sum=$(echo "$sum + $t" | bc)
      (( t < min )) && min=$t
      (( t > max )) && max=$t
    else
      fail=$((fail+1))
    fi
  done
  if (( ok > 0 )); then
    avg=$(echo "scale=2; $sum / $ok" | bc)
    echo "$ok|$fail|$avg|$min|$max"
  else
    echo "0|$fail|TIMEOUT|0|0"
  fi
}

echo
echo -e "${BLD}${CYN}DNS PROVIDER NET SCORE BENCHMARK${RST}"
echo -e "${DIM}Domains tested: ${#DOMAINS[@]} | Queries per domain per server: ${QUERIES_PER_DOMAIN} | Timeout: ${TIMEOUT}s${RST}"
echo

TOTAL=${#PROVIDERS[@]}
IDX=0
RESULTS_FILE="$TMPDIR/results.tsv"
> "$RESULTS_FILE"

for entry in "${PROVIDERS[@]}"; do
  IDX=$((IDX+1))
  IFS='|' read -r family variant ips_csv <<< "$entry"
  IFS=',' read -r -a ips <<< "$ips_csv"

  family_sanitized=$(echo "$family" | tr ' ' '_')
  variant_sanitized=$(echo "$variant" | tr ' ' '_')
  detail_file="$TMPDIR/${family_sanitized}__${variant_sanitized}.tsv"
  > "$detail_file"

  printf "\r${DIM}[%2d/%2d] %-24s %-22s${RST}" "$IDX" "$TOTAL" "$family" "$variant"

  total_ok=0
  total_fail=0
  total_sum=0
  successful_domains=0
  blocked_domains=0
  timeout_domains=0

  for domain in "${DOMAINS[@]}"; do
    best_avg=""
    best_ip=""
    domain_ok=0
    domain_fail=0

    for ip in "${ips[@]}"; do
      probe=$(probe_server "$ip" "$domain" "$QUERIES_PER_DOMAIN")
      IFS='|' read -r ok fail avg min max <<< "$probe"
      domain_ok=$((domain_ok + ok))
      domain_fail=$((domain_fail + fail))

      if [[ "$avg" != "TIMEOUT" ]]; then
        if [[ -z "$best_avg" ]] || (( $(echo "$avg < $best_avg" | bc -l) )); then
          best_avg="$avg"
          best_ip="$ip"
        fi
      fi
    done

    if [[ -n "$best_avg" ]]; then
      successful_domains=$((successful_domains + 1))
      total_ok=$((total_ok + domain_ok))
      total_fail=$((total_fail + domain_fail))
      total_sum=$(echo "$total_sum + $best_avg" | bc)
      status="RESOLVED"
      avg_out="$best_avg"
    else
      timeout_domains=$((timeout_domains + 1))
      total_fail=$((total_fail + domain_fail))
      status="BLOCKED_OR_TIMEOUT"
      avg_out="TIMEOUT"
      blocked_domains=$((blocked_domains + 1))
      best_ip="-"
    fi

    printf "%s\t%s\t%s\t%s\n" "$domain" "$status" "$avg_out" "$best_ip" >> "$detail_file"
  done

  if (( successful_domains > 0 )); then
    mean_avg=$(echo "scale=2; $total_sum / $successful_domains" | bc)
  else
    mean_avg="9999"
  fi

  availability_pct=$(echo "scale=2; ($successful_domains * 100) / ${#DOMAINS[@]}" | bc)
  failure_pct=$(echo "scale=2; ($total_fail * 100) / (($total_ok + $total_fail)==0 ? 1 : ($total_ok + $total_fail))" | bc)

  # Net score: higher is better.
  # Start with availability, subtract latency pressure, subtract heavy failure rate,
  # add intent bonus when blocking is expected for filtering variants.
  intent_bonus=0
  case "$variant" in
    *Family*|*Adult*|*Malware*|*Security*)
      if (( blocked_domains > 0 )); then intent_bonus=$((blocked_domains * 2)); fi
      ;;
  esac

  latency_penalty=$(awk -v a="$mean_avg" 'BEGIN { printf "%.2f", a / 8 }')
  raw_score=$(awk -v avail="$availability_pct" -v latp="$latency_penalty" -v failp="$failure_pct" -v bonus="$intent_bonus" 'BEGIN { s=(avail*1.0) - latp - (failp*0.7) + bonus; if (s<0) s=0; printf "%.2f", s }')

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$family" "$variant" "$availability_pct" "$mean_avg" "$successful_domains/${#DOMAINS[@]}" "$blocked_domains" "$total_fail" "$raw_score" "$detail_file" >> "$RESULTS_FILE"
done
printf "\r%80s\r" ""

SORTED_FILE="$TMPDIR/sorted.tsv"
sort -t$'\t' -k8,8nr -k4,4n "$RESULTS_FILE" > "$SORTED_FILE"

CSVFILE="$HOME/dns-provider-netscore-$(date +%Y%m%d-%H%M%S).csv"
{
  echo 'rank,provider,variant,availability_percent,mean_latency_ms,domains_resolved,domains_blocked_or_timeout,total_failed_queries,net_score'
  awk -F'\t' '{printf "%d,\"%s\",\"%s\",%s,%s,\"%s\",%s,%s,%s\n", NR,$1,$2,$3,$4,$5,$6,$7,$8}' "$SORTED_FILE"
} > "$CSVFILE"

DETAIL_DIR="$HOME/dns-provider-details-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DETAIL_DIR"
while IFS=$'\t' read -r family variant availability mean resolved blocked fails score detail; do
  cp "$detail" "$DETAIL_DIR/$(echo "${family}_${variant}" | tr ' /+' '___').tsv"
done < "$SORTED_FILE"

echo -e "${BLD}Ranked by net score${RST}"
printf "%-4s %-22s %-22s %8s %10s %12s %9s %10s\n" "#" "Provider" "Variant" "Avail%" "Avg ms" "Resolved" "Blocked" "NetScore"
printf '%.0s-' {1..104}; echo

rank=0
while IFS=$'\t' read -r family variant availability mean resolved blocked fails score detail; do
  rank=$((rank+1))
  color="$RST"
  if (( $(echo "$score >= 90" | bc -l) )); then color="$GRN"; elif (( $(echo "$score >= 70" | bc -l) )); then color="$YLW"; else color="$RED"; fi
  printf "%s%-4s %-22.22s %-22.22s %8s %10s %12s %9s %10s${RST}\n" \
    "$color" "$rank" "$family" "$variant" "$availability" "$mean" "$resolved" "$blocked" "$score"
done < "$SORTED_FILE"

cat <<EOF

Score model:
- Availability%: percent of target domains that resolved.
- Avg ms: best average latency per domain across that provider's listed IPv4 servers.
- Blocked: domains that returned no answer from any listed IPv4 server.
- NetScore: availability minus latency/failure penalties, plus small bonus for filtering profiles that actually block domains.

Saved summary CSV: $CSVFILE
Saved per-provider detail TSVs: $DETAIL_DIR
EOF
