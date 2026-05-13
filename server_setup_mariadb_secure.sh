#!/usr/bin/env bash
set -euo pipefail

# Run this on the Raspberry Pi server (as root):
# sudo ./server_setup_mariadb_secure.sh

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

read -rp "LAN CIDR to allow DB access from (example 192.168.1.0/24, any=0.0.0.0/0): " ALLOW_CIDR
read -rp "Create app DB user name [app_reader]: " APP_USER
APP_USER=${APP_USER:-app_reader}
read -rsp "Create app DB user password: " APP_PASS
echo

if [[ -z "$ALLOW_CIDR" ]]; then
  ALLOW_CIDR="0.0.0.0/0"
fi

# MariaDB user host uses patterns, not CIDR. Map "any" network to '%'.
MYSQL_HOST="$ALLOW_CIDR"
if [[ "$ALLOW_CIDR" == "0.0.0.0" || "$ALLOW_CIDR" == "0.0.0.0/0" ]]; then
  MYSQL_HOST="%"
fi

if [[ -z "$APP_PASS" ]]; then
  echo "Password cannot be empty"
  exit 1
fi

echo "[*] Installing MariaDB server..."
apt update
apt install -y mariadb-server

systemctl enable mariadb
systemctl restart mariadb

# Bind on all interfaces for lab use; firewall and grants restrict access.
MYSQL_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
if grep -q '^bind-address' "$MYSQL_CNF"; then
  sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$MYSQL_CNF"
else
  printf '\nbind-address = 0.0.0.0\n' >> "$MYSQL_CNF"
fi

systemctl restart mariadb

# Apply basic hardening and create demo database.
mysql <<SQL
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS demo_security;
USE demo_security;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash CHAR(64) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO users (username, password_hash, role)
VALUES
  ('alice', SHA2('Alice_2026_Strong!', 256), 'admin'),
  ('bob', SHA2('Bob_2026_Strong!', 256), 'user'),
  ('carol', SHA2('Carol_2026_Strong!', 256), 'user');

CREATE USER IF NOT EXISTS '${APP_USER}'@'${MYSQL_HOST}' IDENTIFIED BY '${APP_PASS}';
GRANT SELECT ON demo_security.* TO '${APP_USER}'@'${MYSQL_HOST}';
FLUSH PRIVILEGES;
SQL

echo "[*] Enforcing simple firewall rule for 3306..."
if command -v nft >/dev/null 2>&1; then
  # Adds temporary runtime rule if table/chain exists. Safe no-op when missing.
  nft add rule inet filter input ip saddr "$ALLOW_CIDR" tcp dport 3306 accept 2>/dev/null || true
  nft add rule inet filter input tcp dport 3306 drop 2>/dev/null || true
fi

echo

echo "[+] MariaDB configured with basic hardening."
echo "[+] Demo DB: demo_security"
echo "[+] Demo table: users"
echo "[+] Remote read-only user: ${APP_USER}@${MYSQL_HOST}"
echo "[!] Ensure your nftables rules are persisted in your own firewall config."
