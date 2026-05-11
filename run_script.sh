#!/usr/bin/env bash
set -euo pipefail

# Recon script for Debian/Kali — non-destructive by default.
# Usage: sudo ./run_script.sh
# Options: --target IP --aggressive (optional, more intrusive checks)

TARGET=""
AGGRESSIVE=0
REPORT_DIR="reports"
PORTS="22,21,80,443,53,3306,9090,1514,1515"

function usage(){
  cat <<EOF
Usage: sudo $0 --target 192.168.1.50 [--aggressive]

By default this script performs non-destructive checks (nmap default scripts, banner grabs,
HTTP header checks, DNS queries, SSL cert fetch). Pass --aggressive to enable optional
checks (AXFR attempt, anonymous FTP test, simple HTTP param probe).

Make sure required tools are installed: nmap, curl, dig, openssl, nc (netcat).
To install on Debian/Kali: sudo apt update && sudo apt install -y nmap curl dnsutils openssl netcat
EOF
}

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2;;
    --aggressive) AGGRESSIVE=1; shift 1;;
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

log "Starting passive reconnaissance for $TARGET (aggressive=$AGGRESSIVE)"

# 1) Quick nmap default scripts and service/version on common ports
log "Running nmap default scripts on common ports: $PORTS"
nmap -Pn -sV -p $PORTS --script default -oA "$OUTDIR/nmap_default" "$TARGET" | tee -a "$OUTDIR/run.log"

sleep 2

# 2) HTTP checks (headers + basic security headers)
for p in 80 443 9090; do
  if grep -q "${p}/open" "$OUTDIR/nmap_default.nmap" 2>/dev/null || grep -q ":${p}/tcp" "$OUTDIR/nmap_default.nmap" 2>/dev/null || netstat -an 2>/dev/null | true; then
    log "Checking HTTP(S) on port $p"
    proto="http"
    if [[ $p -eq 443 ]]; then proto="https"; fi
    curl -sS -I --max-time 10 "$proto://$TARGET:$p/" -o "$OUTDIR/http_${p}.headers" || true
    # extract common security headers
    awk 'BEGIN{IGNORECASE=1} /Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options|Content-Security-Policy|Referrer-Policy/ {print}' "$OUTDIR/http_${p}.headers" > "$OUTDIR/http_${p}.secheaders" || true
  fi
done

sleep 1

# 3) SSL certificate grab (if 443 open)
if grep -q "443/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
  log "Fetching SSL certificate from $TARGET:443"
  echo | openssl s_client -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null | openssl x509 -noout -text > "$OUTDIR/ssl_443_cert.txt" || true
fi

sleep 1

# 4) DNS queries (non-intrusive) — SOA, NS, MX, A
log "Running DNS queries against $TARGET (SOA, NS, MX, A)"
for t in SOA NS MX A; do
  dig +noall +answer -t $t @$TARGET | tee -a "$OUTDIR/dns_${t}.txt" || true
done

# optional AXFR if aggressive
if [[ $AGGRESSIVE -eq 1 ]]; then
  read -rp "(Aggressive) Try AXFR (zone transfer) against target? y/N: " axfrans
  if [[ "$axfrans" =~ ^[Yy]$ ]]; then
    log "Attempting AXFR against target"
    dig @$TARGET AXFR +noall +answer | tee "$OUTDIR/dns_axfr.txt" || true
  fi
fi

sleep 1

# 5) FTP anonymous check (optional/aggressive)
if [[ $AGGRESSIVE -eq 1 ]]; then
  if grep -q "21/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
    read -rp "(Aggressive) Test anonymous FTP login? y/N: " ftpants
    if [[ "$ftpants" =~ ^[Yy]$ ]]; then
      log "Testing anonymous FTP login"
      # using netcat for a simple banner/login test
      { echo -e "USER anonymous\r\nPASS anonymous@\r\nQUIT\r\n"; } | nc -w 5 "$TARGET" 21 > "$OUTDIR/ftp_anonymous.txt" || true
    fi
  fi
fi

sleep 1

# 6) MariaDB/MySQL check (banner only)
if grep -q "3306/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
  log "MySQL/MariaDB port open (3306) — grabbing banner"
  timeout 5 bash -c "echo | nc -w 5 $TARGET 3306" > "$OUTDIR/mysql_banner.txt" || true
fi

sleep 1

# 7) Check for Cockpit (9090)
if grep -q "9090/tcp.*open" "$OUTDIR/nmap_default.nmap" 2>/dev/null; then
  log "Cockpit detected on 9090 — fetching headers"
  curl -sS -I --max-time 10 "http://$TARGET:9090/" -o "$OUTDIR/cockpit_headers.txt" || true
fi

sleep 1

# 8) Port state summary and inference about firewall
log "Summarizing port states"
grep -E "open|filtered|closed" "$OUTDIR/nmap_default.nmap" | tee "$OUTDIR/port_states.txt" || true

# 9) Optional simple HTTP parameter probe (aggressive)
if [[ $AGGRESSIVE -eq 1 ]]; then
  # Very simple and safe probe: check if adding a single quote changes response length significantly
  if [[ -f "$OUTDIR/http_80.headers" || -f "$OUTDIR/http_443.headers" ]]; then
    read -rp "(Aggressive) Run simple HTTP param probe on /?id=1 ? y/N: " httpprobe
    if [[ "$httpprobe" =~ ^[Yy]$ ]]; then
      for proto in http https; do
        for p in 80 443; do
          if [[ $p -eq 80 && -f "$OUTDIR/http_80.headers" ]] || [[ $p -eq 443 && -f "$OUTDIR/http_443.headers" ]]; then
            url="$proto://$TARGET:$p/"
            resp1=$(curl -sS --max-time 10 "$url?id=1") || true
            resp2=$(curl -sS --max-time 10 "$url?id=1'" ) || true
            echo "LEN_NORMAL=${#resp1}" > "$OUTDIR/http_probe_${p}.txt"
            echo "LEN_INJECT=${#resp2}" >> "$OUTDIR/http_probe_${p}.txt"
          fi
        done
      done
    fi
  fi
fi

log "Recon finished. Reports in: $OUTDIR"

echo
ls -l "$OUTDIR"

echo "Done. Review the files in $OUTDIR."
