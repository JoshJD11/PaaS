#!/bin/bash
set -e

echo "================================================"
echo "  FTP Jail — vsftpd (simula FreeBSD jail)"
echo "================================================"

SHARED=/srv/ftp/shared

# Archivo de bienvenida para verificar que el share funciona
cat > "$SHARED/README.txt" << TXT
FileServer PaaS.net — FTP Jail
Protocolo : FTP (vsftpd)
Usuario   : ftpuser
Directorio: /srv/ftp/shared
TXT

chown ftpuser:ftpuser "$SHARED/README.txt"

echo "[FTP] Directorio compartido: $SHARED"
echo "[FTP] Iniciando vsftpd..."

exec vsftpd /etc/vsftpd.conf
