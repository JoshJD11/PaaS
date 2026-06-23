#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==> Instalando init y utilidades de red (apt con reintentos)..."
apt-get update -o Acquire::Retries=10
apt-get install -y -o Acquire::Retries=10 --no-install-recommends \
    systemd-sysv udev iproute2 isc-dhcp-client nano iputils-ping

echo "==> Configurando el sistema Ubuntu..."
echo "paas-thinclient" > /etc/hostname

cat > /etc/motd << 'MOTD'

==================================================
  PaaS.net - Thin Client Server (estilo LTSP)
  Ubuntu 22.04 arrancado 100% por red:
  DHCP -> PXE -> TFTP (kernel/initrd) -> NFS (root)
  No se utilizo ningun disco local en este cliente.
==================================================
Comandos utiles para verificar:
  cat /etc/os-release   (confirma que es Ubuntu)
  uname -a              (kernel)
  ip addr               (IP obtenida por DHCP)
  mount | grep nfs      (raiz montada por NFS)

MOTD

sed -i 's|^root:[^:]*:|root::|' /etc/shadow

systemctl enable serial-getty@ttyS0.service 2>/dev/null || true
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 115200,38400,9600 vt220
AUTOLOGIN

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-wired.network << 'NET'
[Match]
Name=en* eth*

[Network]
DHCP=yes
NET
# Arrancar en modo consola (multi-user), NO en modo grafico. Sin
# esto systemd intenta arrancar "graphical.target" (un escritorio
# que no instalamos) y se cuelga esperando servicios que no existen.
ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "==> Empaquetando rootfs Ubuntu..."
mkdir -p /artifacts
tar --exclude='./artifacts' \
    --exclude='./proc/*' --exclude='./sys/*' --exclude='./dev/*' \
    --exclude='./usr/local/bin/build-rootfs.sh' \
    -C / -cf /artifacts/rootfs.tar .
echo "==> rootfs Ubuntu empaquetado. Tamano:"
ls -lh /artifacts/rootfs.tar
