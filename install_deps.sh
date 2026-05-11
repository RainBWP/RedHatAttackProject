#!/usr/bin/env bash

# Install dependencies for the reconnaissance script on Debian/Kali
# Usage: sudo ./install_deps.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use: sudo $0)"
  exit 1
fi

echo "[*] Updating package lists..."
apt update

echo "[*] Installing required tools for reconnaissance..."
apt install -y \
  nmap \
  curl \
  dnsutils \
  openssl \
  netcat-openbsd

echo "[*] Verifying installations..."
for tool in nmap curl dig openssl nc; do
  if command -v "$tool" &> /dev/null; then
    echo "  [✓] $tool"
  else
    echo "  [✗] $tool (failed to install)"
    exit 1
  fi
done

echo "[✓] All dependencies installed successfully."
echo ""
echo "Next step: Run ./run_script.sh --target <IP>"
