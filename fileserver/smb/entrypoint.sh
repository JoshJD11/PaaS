#!/bin/bash
set -e

echo "================================================"
echo "  SMB Jail — Samba (simula FreeBSD jail)"
echo "================================================"

SHARED=/srv/smb/shared

# Crear usuario Linux + cuenta Samba en tiempo de ejecución
# (no en build) para asegurar que la base TDB existe
if ! id smbuser &>/dev/null; then
    useradd -s /bin/bash smbuser
fi

printf 'smbpassword\nsmbpassword\n' | smbpasswd -s -a smbuser
smbpasswd -e smbuser

# Archivo de bienvenida
cat > "$SHARED/README.txt" << TXT
FileServer PaaS.net — SMB Jail
Protocolo : SMB/CIFS (Samba)
Recurso   : //smb_jail/shared
Usuario   : smbuser
TXT
chown smbuser:smbuser "$SHARED/README.txt"

echo "[SMB] Validando configuración..."
testparm -s

echo "[SMB] Iniciando smbd..."
exec smbd --foreground --no-process-group --debug-stdout
