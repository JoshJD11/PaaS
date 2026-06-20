#!/bin/bash
set -e

echo "==> Verificando rootfs en el volumen..."
mkdir -p /srv/ltsp/rootfs
if [ -z "$(ls -A /srv/ltsp/rootfs 2>/dev/null)" ]; then
    echo "==> Primer arranque: extrayendo rootfs en el volumen montado..."
    tar -C /srv/ltsp/rootfs -xf /opt/ltsp-rootfs.tar
fi

echo "==> Preparando servidor NFS..."
mkdir -p /var/lib/nfs/v4recovery
mount -t nfsd nfsd /proc/fs/nfsd 2>/dev/null || true

rpcbind -w 2>/dev/null || true
exportfs -ra

echo "==> Iniciando rpc.mountd y rpc.nfsd (NFSv3)..."
/usr/sbin/rpc.nfsd 8
/usr/sbin/rpc.mountd --no-nfs-version 4

echo "==> Iniciando TFTP en 0.0.0.0:69, sirviendo /srv/tftp..."
exec /usr/sbin/in.tftpd --foreground --secure --address 0.0.0.0:69 /srv/tftp
