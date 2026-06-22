#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Variables de configuracion (con valores por defecto, sobreescribibles
# desde docker-compose.yml mediante "environment:")
# ---------------------------------------------------------------------------
DOMAIN_REALM=${DOMAIN_REALM:-LAB.LOCAL}        # Realm Kerberos / dominio AD
DOMAIN_NETBIOS=${DOMAIN_NETBIOS:-LAB}          # Nombre NetBIOS del dominio
ADMIN_PASSWORD=${ADMIN_PASSWORD:-Passw0rd123!} # Password de Administrator
ROLE=${ROLE:-primary}                          # primary | secondary
PRIMARY_DC_IP=${PRIMARY_DC_IP:-172.28.0.10}    # IP del primer DC (la "AD")
MY_IP=${MY_IP:-172.28.0.11}                    # IP propia de este contenedor
MY_HOSTNAME=$(hostname)

STATE_FILE="/var/lib/samba/private/sam.ldb"

echo "============================================================"
echo " Rol: ${ROLE}  |  Host: ${MY_HOSTNAME}  |  Realm: ${DOMAIN_REALM}"
echo "============================================================"

if [ ! -f "$STATE_FILE" ]; then
    echo "[entrypoint] No hay configuracion previa. Iniciando aprovisionamiento..."

    # Mientras se aprovisiona / se hace el join, la resolucion DNS debe
    # apuntar al DC primario (quien sabe resolver los registros SRV de AD)
    echo "nameserver ${PRIMARY_DC_IP}" > /etc/resolv.conf

    if [ "$ROLE" = "primary" ]; then
        echo "[entrypoint] Creando un nuevo dominio Active Directory: ${DOMAIN_REALM}"
        samba-tool domain provision \
            --use-rfc2307 \
            --domain="${DOMAIN_NETBIOS}" \
            --realm="${DOMAIN_REALM}" \
            --server-role=dc \
            --dns-backend=SAMBA_INTERNAL \
            --adminpass="${ADMIN_PASSWORD}" \
            --host-name="${MY_HOSTNAME}"
    else
        echo "[entrypoint] Esperando a que el DC primario (${PRIMARY_DC_IP}) responda LDAP..."
        until ldapsearch -x -H "ldap://${PRIMARY_DC_IP}" -b "" -s base >/dev/null 2>&1; do
            echo "    ... aun no disponible, reintentando en 3s"
            sleep 3
        done

        echo "[entrypoint] Uniendo este servidor como controlador de dominio adicional"
        samba-tool domain join "${DOMAIN_REALM}" DC \
            -U"${DOMAIN_NETBIOS}\\administrator" \
            --password="${ADMIN_PASSWORD}" \
            --dns-backend=SAMBA_INTERNAL
    fi

    # Fix conocido para entornos Docker: el modulo acl_xattr necesita
    # xattrs reales en el filesystem, lo cual no siempre esta disponible
    # segun el storage driver. xattr_tdb evita ese problema.
    sed -i 's/acl_xattr/xattr_tdb/' /etc/samba/smb.conf

    echo "[entrypoint] Aprovisionamiento / join completado."
else
    echo "[entrypoint] Configuracion existente detectada (volumen persistente)."
    echo "[entrypoint] Se omite aprovisionamiento, se reutiliza la base de datos AD."
fi

# A partir de aqui este servidor ya es (o ya era) un DC: usa su propio
# servicio DNS interno de Samba, con el otro DC como respaldo
printf "nameserver %s\nnameserver %s\n" "${MY_IP}" "${PRIMARY_DC_IP}" > /etc/resolv.conf

# Copiamos el krb5.conf generado por Samba para que kinit/klist funcionen
if [ -f /var/lib/samba/private/krb5.conf ]; then
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi

echo "[entrypoint] Iniciando el servicio Samba (modo Active Directory DC)..."
exec /usr/sbin/samba --foreground --no-process-group
