FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Paquetes necesarios para Samba como AD DC, herramientas de
# diagnostico LDAP/Kerberos y utilidades de red para las pruebas
RUN apt-get update && apt-get install -y \
        samba \
        samba-dsdb-modules \
        samba-vfs-modules \
        smbclient \
        winbind \
        libnss-winbind \
        libpam-winbind \
        krb5-user \
        krb5-config \
        ldap-utils \
        libsasl2-modules-gssapi-mit \
        dnsutils \
        iputils-ping \
        attr \
        acl \
        net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Eliminamos el smb.conf por defecto: samba-tool generará uno nuevo
# al aprovisionar (dc1) o unirse al dominio (dc2)
RUN rm -f /etc/samba/smb.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Puertos estándar de un controlador de dominio Active Directory
EXPOSE 53/tcp 53/udp \
       88/tcp 88/udp \
       135/tcp \
       137/udp 138/udp 139/tcp \
       389/tcp 389/udp \
       445/tcp \
       464/tcp 464/udp \
       636/tcp \
       3268/tcp 3269/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]