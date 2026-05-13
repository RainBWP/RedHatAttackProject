# Red Hat Attack Project — Robustness Assessment
**Intercomunicaciones en la red y Ciberseguridad**

Scripts de **comprobacion y robustez no destructiva** para Debian/Kali Linux contra un servidor Raspberry Pi con multiples servicios.

### Checar Logs en Pi
```bash
ssh pi@[ip]
sudo tail -f /var/log/suricata/fast.log
```
---
### Configuracion de IPStatuc
#### **Raspberry**
```bash
nmcli connection show
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.10.2/24 ipv4.method manual
sudo nmcli con up "Wired connection 1"
```
#### **Windows**
1. Panel de Control
2. Redes e Internet
3. Ethernet > Propiedades
4. IPv4 Protocol
5. Configurar estas cosas
    - IP: `192.168.10.1`
    - Mask: `255.255.255.0`
    - Gateway: *empty*

Probar haciendo `ping 192.168.10.2` a la berry
### Configuracion de DHCP
#### **Raspberry**
```bash
sudo nmcli con mod "Wired connection 1" ipv4.method auto
sudo nmcli con mod "Wired connection 1" ipv4.addresses ""
sudo nmcli con up "Wired connection 1"
```
---

## Servicios Objetivo

- **Raspberry Pi OS Lite 64-bit** — Sistema operativo
- **OpenSSH** — Acceso remoto (puerto 22)
- **Nginx** — HTTP/HTTPS (puertos 80, 443)
- **vsftpd** — FTP (puerto 21)
- **Bind** — DNS (puerto 53)
- **MariaDB** — Base de datos (puerto 3306)
- **nftables** — Firewall
- **Fail2ban** — Bloqueo automático
- **Suricata** — IDS (Sistema de detección de intrusos)
- **tcpdump** — Captura de tráfico
- **Wazuh Agent** — Envío de logs
- **Cockpit** — Dashboard de administración (puerto 9090)

---

## Instalación Rápida

```bash
chmod +x run_me.sh
sudo ./run_me.sh
```

### Preparar MariaDB seguro en el servidor (Raspberry)

Ejecuta este script directamente en el servidor por SSH:

```bash
sudo ./server_setup_mariadb_secure.sh
```

Este script:
- Instala MariaDB Server
- Aplica hardening basico (sin users anonimos, sin DB de test)
- Crea DB `demo_security`
- Crea tabla `users` con hashes SHA-256
- Crea usuario read-only para pruebas desde red autorizada


## Requisitos Previos

- **Debian 11+** o **Kali Linux** (cualquier versión reciente)
- **Acceso root** (necesario para algunos escaneos)
- **Red IP local** con el Raspberry Pi accesible
- **Herramientas instaladas** (ver `install_deps.sh`)

