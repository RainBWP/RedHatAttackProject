#!/usr/bin/env bash
set -euo pipefail

# Robustness check script for Debian/Kali — non-destructive only.
# Usage: ./run_script.sh --target IP [--focus dns,http,mysql]

TARGET=""
REPORT_DIR="reports"
PORTS="22,21,80,443,53,3306,9090,1514,1515"
FOCUS="dns,http,mysql"

function usage(){
  cat <<EOF
Usage: $0 --target 192.168.1.50 [--focus dns,http,mysql]

This script performs only non-destructive robustness checks:
- DNS: NSID/version exposure, recursion behavior, basic record responses
- HTTP: response headers, security headers, allowed methods, bounded latency sample
- MySQL: port/service fingerprint and optional read-only validation with provided credentials

Make sure required tools are installed: nmap, curl, dig, openssl, nc (netcat), mariadb-client (optional).
To install on Debian/Kali: sudo apt update && sudo apt install -y nmap curl dnsutils openssl netcat-openbsd mariadb-client
EOF
}

has_focus(){
  local name="$1"
  [[ ",$FOCUS," == *",$name,"* ]]
}

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2;;
    --focus) FOCUS="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ -z "$TARGET" ]]; then
  read -rp "Target IPv4 (local) > " TARGET
fi

if [[ -z "$TARGET" ]]; then
  echo "No target provided. Exiting."; exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="$REPORT_DIR/${TARGET}_$TIMESTAMP"
mkdir -p "$OUTDIR"

echo "Report dir: $OUTDIR"

# helper
log(){
  echo "[$(date '+%F %T')] $*" | tee -a "$OUTDIR/run.log"
}

need_cmd(){
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd"
    echo "Install dependencies with: sudo ./install_deps.sh"
    exit 1
  fi
}

need_cmd nmap
need_cmd curl
need_cmd dig
need_cmd openssl
need_cmd nc

log "Starting robustness checks for $TARGET (focus=$FOCUS)"

# 1) Quick nmap default scripts and service/version on common ports
log "Running nmap default scripts on common ports: $PORTS"
nmap -Pn -sV -p $PORTS --script default -oA "$OUTDIR/nmap_default" "$TARGET" | tee -a "$OUTDIR/run.log"

sleep 2

# 2) DNS checks (safe only)
if has_focus "dns"; then
  if grep -q "53/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
    log "Running DNS robustness checks"

    # Basic DNS answers
    for t in SOA NS MX A; do
      dig +noall +answer -t "$t" @"$TARGET" | tee -a "$OUTDIR/dns_${t}.txt" || true
    done

    # NSID query output (the part you highlighted)
    dig +nsid @"$TARGET" . SOA +noall +answer +authority +additional > "$OUTDIR/dns_nsid.txt" || true

    # Version disclosure test (CH class)
    dig @"$TARGET" CHAOS TXT version.bind +short > "$OUTDIR/dns_version_bind.txt" || true

    # Recursion behavior test against external domain
    dig @"$TARGET" example.com A +time=3 +tries=1 +comments > "$OUTDIR/dns_recursion_test.txt" || true

    # Optional DNSSEC-related response visibility
    dig @"$TARGET" . DNSKEY +dnssec +time=3 +tries=1 > "$OUTDIR/dns_dnssec_probe.txt" || true
  else
    log "DNS (53/tcp) is not open in nmap results; skipping DNS checks"
  fi
fi

sleep 1

# 3) HTTP checks (safe only)
if has_focus "http"; then
  for p in 80 443 9090; do
    if grep -q "${p}/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
      log "Checking HTTP(S) on port $p"
      proto="http"
      if [[ $p -eq 443 ]]; then proto="https"; fi

      curl -sS -I --max-time 10 "$proto://$TARGET:$p/" -o "$OUTDIR/http_${p}.headers" || true

      # Extract common security headers for quick scoring in the report
      awk 'BEGIN{IGNORECASE=1} /Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options|Content-Security-Policy|Referrer-Policy|Permissions-Policy/ {print}' "$OUTDIR/http_${p}.headers" > "$OUTDIR/http_${p}.secheaders" || true

      # Supported HTTP methods (informational)
      nmap -Pn -p "$p" --script http-methods --script-args http-methods.url-path=/ "$TARGET" > "$OUTDIR/http_${p}_methods.txt" || true

      # Bounded latency sample (20 sequential requests)
      : > "$OUTDIR/http_${p}_latency.txt"
      for i in $(seq 1 20); do
        curl -sS -o /dev/null --max-time 5 -w "req=${i} code=%{http_code} total=%{time_total}\n" "$proto://$TARGET:$p/" >> "$OUTDIR/http_${p}_latency.txt" || true
      done

      # SSL certificate grab for HTTPS
      if [[ $p -eq 443 ]]; then
        echo | openssl s_client -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null | openssl x509 -noout -text > "$OUTDIR/ssl_443_cert.txt" || true
      fi
    fi
  done
fi

sleep 1

# 4) MySQL checks (safe only)
if has_focus "mysql"; then
  if grep -q "3306/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
    log "MySQL/MariaDB port open (3306) — running safe checks"

    timeout 5 bash -c "echo | nc -w 5 $TARGET 3306" > "$OUTDIR/mysql_banner.txt" || true
    nmap -Pn -p 3306 --script mysql-info "$TARGET" > "$OUTDIR/mysql_info.txt" || true

    if command -v mysql >/dev/null 2>&1; then
      read -rp "Run read-only SQL validation using credentials? y/N: " mysqlcheck
      if [[ "$mysqlcheck" =~ ^[Yy]$ ]]; then
        read -rp "MySQL user: " MYSQL_USER
        read -rsp "MySQL password: " MYSQL_PASS
        echo
        read -rp "Database name (example: demo_security): " MYSQL_DB

        MYSQL_PWD="$MYSQL_PASS" mysql -h "$TARGET" -u "$MYSQL_USER" -D "$MYSQL_DB" --connect-timeout=5 -e "SHOW TABLES;" > "$OUTDIR/mysql_tables.txt" 2> "$OUTDIR/mysql_tables.err" || true
        MYSQL_PWD="$MYSQL_PASS" mysql -h "$TARGET" -u "$MYSQL_USER" -D "$MYSQL_DB" --connect-timeout=5 -e "SELECT COUNT(*) AS users_count FROM users;" > "$OUTDIR/mysql_users_count.txt" 2> "$OUTDIR/mysql_users_count.err" || true
      fi
    else
      log "mysql client not found; skipping credentialed MySQL validation"
    fi
  fi
fi

sleep 1

# 5) Port state summary
log "Summarizing port states"
grep -E "open|filtered|closed" "$OUTDIR/nmap_default.nmap" | tee "$OUTDIR/port_states.txt" || true

log "Recon finished. Reports in: $OUTDIR"

echo
ls -l "$OUTDIR"

echo "Done. Review the files in $OUTDIR."
