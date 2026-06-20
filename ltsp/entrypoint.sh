#!/bin/bash
set -e

echo "==> Verificando rootfs en el volumen..."
mkdir -p /srv/ltsp/rootfs
if [ -z "$(ls -A /srv/ltsp/rootfs 2>/dev/null)" ]; then
    echo "==> Primer arranque: extrayendo rootfs en el volumen montado..."
    tar -C /srv/ltsp/rootfs -xf /opt/ltsp-rootfs.tar
fi

echo "==> Iniciando rpcbind..."
rpcbind || true
sleep 2

echo "==> Iniciando servidor NFS en espacio de usuario (unfs3)..."
echo "    Exports configurados:"
cat /etc/exports
unfsd -d -s -n 2049 -m 2049 -l 0.0.0.0 -e /etc/exports &
sleep 2

echo "==> Servicios RPC registrados tras iniciar unfs3:"
rpcinfo -p 127.0.0.1 || echo "    (aviso: rpcbind sin registros, se usara montaje por puerto directo)"

echo "==> Iniciando TFTP en 0.0.0.0:69, sirviendo /srv/tftp..."
exec /usr/sbin/in.tftpd --foreground --secure --address 0.0.0.0:69 /srv/tftp
