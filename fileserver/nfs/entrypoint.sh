#!/bin/bash
set -e

echo "================================================"
echo "  NFS Jail — nfs-kernel-server (simula FreeBSD jail)"
echo "================================================"

SHARED=/srv/nfs/shared

# Archivo de bienvenida
cat > "$SHARED/README.txt" << TXT
FileServer PaaS.net — NFS Jail
Protocolo : NFS v3/v4
Exportado : /srv/nfs/shared
TXT

chmod 777 "$SHARED/README.txt"

# El pseudo-filesystem nfsd debe estar montado para que funcione
# el servidor de kernel. Con 'privileged: true' en Docker-Compose
# el host ya expone /proc/fs/nfsd al contenedor.
if ! mountpoint -q /proc/fs/nfsd 2>/dev/null; then
    echo "[NFS] Montando pseudo-fs nfsd..."
    mount -t nfsd nfsd /proc/fs/nfsd || {
        echo "[NFS] ADVERTENCIA: no se pudo montar nfsd."
        echo "[NFS] Asegúrese de que el módulo 'nfsd' esté cargado en el host:"
        echo "[NFS]   sudo modprobe nfsd"
    }
fi

echo "[NFS] Iniciando rpcbind..."
rpcbind -w || true
sleep 1

echo "[NFS] Exportando shares..."
exportfs -ra

echo "[NFS] Iniciando nfsd (8 threads)..."
rpc.nfsd 8

echo "[NFS] Iniciando mountd..."
rpc.mountd --no-udp &

echo ""
echo "[NFS] Exports activos:"
exportfs -v

echo "[NFS] Servidor listo."
exec sleep infinity