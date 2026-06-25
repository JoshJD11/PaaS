#!/bin/bash
# ============================================================
# mount-all.sh — Cliente Linux del FileServer
# Monta los tres protocolos: NFS, SMB y FTP
# ============================================================

BANNER="================================================"
OK="  ✓"
FAIL="  ✗"

echo "$BANNER"
echo "  FileServer Client — PaaS.net"
echo "  Monta: NFS · SMB · FTP"
echo "$BANNER"

echo ""
echo "[*] Esperando que los servidores inicialicen (20 s)..."
sleep 20

mkdir -p /mnt/nfs /mnt/smb

# ── NFS ──────────────────────────────────────────────────────
echo ""
echo "[$BANNER NFS $BANNER]"
echo "[NFS] Montando nfs_jail:/srv/nfs/shared → /mnt/nfs"
if mount -t nfs \
       -o nolock,nfsvers=3,proto=tcp,port=2049 \
       nfs_jail:/srv/nfs/shared \
       /mnt/nfs 2>&1; then
    echo "$OK NFS montado correctamente"
    echo "    Contenido:"
    ls -la /mnt/nfs/
else
    echo "$FAIL Error montando NFS"
    echo "    Verifique que el módulo 'nfsd' esté cargado en el host:"
    echo "    sudo modprobe nfsd"
fi

# ── SMB ──────────────────────────────────────────────────────
echo ""
echo "[$BANNER SMB $BANNER]"
echo "[SMB] Montando //smb_jail/shared → /mnt/smb"
if mount -t cifs //smb_jail/shared /mnt/smb \
       -o username=smbuser,password=smbpassword,\
uid=0,gid=0,vers=3.0,iocharset=utf8 2>&1; then
    echo "$OK SMB/CIFS montado correctamente"
    echo "    Contenido:"
    ls -la /mnt/smb/
else
    echo "$FAIL Error montando SMB"
fi

# ── FTP ──────────────────────────────────────────────────────
echo ""
echo "[$BANNER FTP $BANNER]"
echo "[FTP] Conectando a ftp_jail y listando archivos..."
if lftp -u ftpuser,ftppassword ftp://ftp_jail \
    -e "set ftp:passive-mode on; set net:timeout 10; ls; bye" 2>&1; then
    echo "$OK FTP: listado exitoso"
else
    echo "$FAIL Error conectando por FTP"
fi

# ── Resumen de montajes ───────────────────────────────────────
echo ""
echo "$BANNER"
echo "  Resumen de montajes"
echo "$BANNER"
df -hT 2>/dev/null | grep -E "Filesystem|nfs|cifs" || true

echo ""
echo "[*] Contenido /mnt/nfs  :"
ls /mnt/nfs/  2>/dev/null || echo "  (no montado)"

echo ""
echo "[*] Contenido /mnt/smb  :"
ls /mnt/smb/  2>/dev/null || echo "  (no montado)"

echo ""
echo "[*] Cliente listo. Para interactuar:"
echo "    docker exec -it fs_client bash"
echo ""

exec sleep infinity
