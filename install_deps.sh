#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

echo "[*] Updating package lists..."
apt update

echo "[*] Installing dependencies..."
apt install -y \
  nmap \
  curl \
  dnsutils \
  openssl \
  netcat-openbsd \
  mariadb-client

echo "[*] Verifying tools..."
for tool in nmap curl dig openssl nc mysql; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  [ok] $tool"
  else
    echo "  [fail] $tool"
    exit 1
  fi
done

echo "[+] Dependencies installed successfully."
