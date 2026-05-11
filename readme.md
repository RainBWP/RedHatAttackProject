# Red Hat Attack Project — Offensive Security Assessment
**Intercomunicaciones en la red y Ciberseguridad**

Script de **reconocimiento y pruebas de seguridad** para Debian/Kali Linux contra un servidor Raspberry Pi con múltiples servicios.



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

### 1. Instalar dependencias

```bash
sudo ./install_deps.sh
```

O manualmente:
```bash
sudo apt update
sudo apt install -y nmap curl dnsutils openssl netcat-openbsd
```

### 2. Dar permisos de ejecución

```bash
chmod +x install_deps.sh run_script.sh
```

---

## Uso

### Modo Pasivo (por defecto)

```bash
sudo ./run_script.sh --target 192.168.1.50
```

O responde de forma interactiva:
```bash
sudo ./run_script.sh
# Te pedirá la dirección IP
```

**Qué hace:**
- Escaneo nmap con scripts de default-scripts
- Obtención de versiones de servicios
- Grabación de headers HTTP/HTTPS
- Fetch de certificados SSL
- Queries DNS (SOA, NS, MX, A)
- Banner grabbing de MySQL/FTP/otros

**Salida:** Carpeta `reports/<IP>_timestamp/` con archivos de análisis

---

### Modo Agresivo (opcional)

```bash
sudo ./run_script.sh --target 192.168.1.50 --aggressive
```

Habilita controles adicionales (interactivos):
- Intento de **AXFR** (zone transfer DNS)
- **FTP anonymous login test**
- **HTTP parameter probe** (simple detección de SQL injection)

Se solicita confirmación antes de cada prueba agresiva.

---

## Estructura de Reportes

```
reports/
└── 192.168.1.50_20260510-143022/
    ├── run.log                          # Log detallado de ejecución
    ├── nmap_default.nmap               # Salida nmap formato nmap
    ├── nmap_default.xml                # Salida nmap formato XML
    ├── nmap_default.gnmap              # Salida nmap formato greppable
    ├── port_states.txt                 # Resumen de puertos abiertos/filtrados
    ├── http_80.headers                 # Headers HTTP puerto 80
    ├── http_443.headers                # Headers HTTPS puerto 443
    ├── http_80.secheaders              # Security headers HTTP
    ├── http_443.secheaders             # Security headers HTTPS
    ├── http_9090.headers               # Headers Cockpit
    ├── ssl_443_cert.txt                # Certificado SSL
    ├── dns_SOA.txt                     # Consulta DNS SOA
    ├── dns_NS.txt                      # Consulta DNS NS
    ├── dns_MX.txt                      # Consulta DNS MX
    ├── dns_A.txt                       # Consulta DNS A
    ├── dns_axfr.txt                    # Zone transfer (si --aggressive)
    ├── ftp_anonymous.txt               # Test FTP anónimo (si --aggressive)
    ├── mysql_banner.txt                # Banner MySQL/MariaDB
    ├── http_probe_80.txt               # HTTP param probe (si --aggressive)
    ├── http_probe_443.txt              # HTTPS param probe (si --aggressive)
    └── cockpit_headers.txt             # Cockpit headers
```

---

## Requisitos Previos

- **Debian 11+** o **Kali Linux** (cualquier versión reciente)
- **Acceso root** (necesario para algunos escaneos)
- **Red IP local** con el Raspberry Pi accesible
- **Herramientas instaladas** (ver `install_deps.sh`)

---

## Detalles Técnicos

### Puertos escaneados
`22, 21, 80, 443, 53, 3306, 9090, 1514, 1515`

### Pruebas no-destructivas
- ✅ Nmap version detection (`-sV`)
- ✅ Default NSE scripts
- ✅ Banner grabbing (HTTP, FTP, MySQL)
- ✅ SSL certificate fetch
- ✅ DNS queries (SOA, NS, MX, A)
- ✅ Security header inspection

### Pruebas agresivas (confirmadas por usuario)
- ⚠️ DNS AXFR attempt
- ⚠️ FTP anonymous login test
- ⚠️ Simple HTTP parameter injection probe

---

## Logs y Debugging

Todos los comandos ejecutados se loguean en `reports/<IP>_timestamp/run.log`.  
Para más verbosidad, edita el script y reemplaza `nmap ... ` con `nmap -vvv ...`

---

## Descargo de Responsabilidad

Este proyecto es **solo para propósitos educativos y de demostración de seguridad autorizada**.  
El usuario es responsable de:
- Obtener **autorización explícita por escrito** antes de usar
- Cumplir con leyes locales y regulaciones de seguridad
- Usar solo contra sistemas propios o con permiso documentado

---

## Licencia

Proyecto interno. Uso restrictivo bajo autorización.

---

## Soporte

Para issues o mejoras:
1. Verifica que todas las dependencias están instaladas
2. Asegúrate de ejecutar con `sudo`
3. Confirma que la IP del target es correcta y accesible
4. Revisa `run.log` para detalles de error