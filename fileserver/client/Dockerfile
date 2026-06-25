FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    # NFS client
    nfs-common \
    # SMB/CIFS client
    cifs-utils \
    # FTP cliente interactivo
    lftp \
    # Utilidades de red
    iputils-ping \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY mount-all.sh /mount-all.sh
RUN chmod +x /mount-all.sh

# Necesita SYS_ADMIN (o privileged) para ejecutar mount(2)
CMD ["/mount-all.sh"]
