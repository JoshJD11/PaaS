#!/bin/bash
set -e

# dhcpd exige que el archivo de leases ya exista
mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases

echo "==> Iniciando dhcpd en la interfaz eth0 (red 172.30.0.0/24)..."

# -f  : foreground (no demoniza, necesario para Docker)
# -d  : manda logs también a stdout/stderr
# -cf : ruta del archivo de configuración
exec dhcpd -f -d \
    -cf /etc/dhcp/dhcpd.conf \
    -lf /var/lib/dhcp/dhcpd.leases \
    eth0
