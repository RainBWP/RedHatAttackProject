# Un script en Linux para Kali-linux 
Simular un ataque de los siguientes sevicios a un servidor rasberry pi 

- Raspberry Pi OS Lite 64-bit
    - Sistema operativo
- OpenSSH
    - Acceso remoto
- Ngin
    - HTTP/HTTPS
- vsftp
    - FTP
- Bind
    - DNS
- MariaDB
    - Base de datos
- nftables
    - Firewall
- Fail2ban
    - Bloqueo automático
- Suricata
    - IDS _Sistema de detección de intrusos_
- tcpdump
    - Captura tráfico
- Wazuh Agent
    - Envío logs
- Cockpit
    - Dashboard administración

## Script logic
1. Instalar paquetes necesarios, para ataques
2. Pedir direccion IPv4 Local para localizar el servidor
3. Para cada uno de los servicios a atacar, ejecutar los programas necesarios
4. Si es posible, intentar con grep o algo parecido, obtener la informacion interesante de este ataque
5. Intentar pasar desapercibido para no hacer ataques de peticione seguidas
6. Intentar bloquear al menos un servicio (Los compatibles)
7. Intentar obtener algo de los servicos como de SQL con un sql inyection
8. Desviar informacion entrante del servidor a la maquina atacante (maquina corriendo script)

## usage
ejecutar un script y ya en Linux (Debian o Kali)
```sh
./run_script.sh
```