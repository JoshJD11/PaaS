# ─────────────────────────────────────────────────────────────
# Thin Client Server (LTSP) para PaaS.net
#
# Etapa "builder": instala un kernel real de Ubuntu y construye
# un initramfs mínimo (BusyBox) + un rootfs mínimo (BusyBox) que
# juntos implementan el mecanismo de arranque sin disco que usa
# LTSP: el cliente hace PXE -> pide por TFTP el kernel/initrd ->
# el initrd levanta red por DHCP -> monta la raíz real por NFS.
#
# Etapa final: solo lo necesario para SERVIR esos archivos
# (tftpd-hpa para TFTP, nfs-kernel-server para NFS, pxelinux
# como bootloader PXE en modo BIOS).
# ─────────────────────────────────────────────────────────────

FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        linux-image-virtual \
        busybox-static \
        kmod zstd cpio gzip && \
    rm -rf /var/lib/apt/lists/*

COPY build-initramfs.sh /usr/local/bin/build-initramfs.sh
COPY build-rootfs.sh /usr/local/bin/build-rootfs.sh
RUN chmod +x /usr/local/bin/build-initramfs.sh /usr/local/bin/build-rootfs.sh && \
    /usr/local/bin/build-initramfs.sh && \
    /usr/local/bin/build-rootfs.sh

# ─────────────────────────────────────────────────────────────
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# unfs3 NO esta empaquetado en Ubuntu 22.04, asi que se compila
# desde su codigo fuente (es un proyecto C pequeno, compila en
# segundos). El resultado es el binario /usr/local/sbin/unfsd.
RUN apt-get update && apt-get install -y --no-install-recommends \
        tftpd-hpa \
        rpcbind \
        pxelinux \
        syslinux-common \
        net-tools \
        ca-certificates \
        git build-essential autoconf automake libtool flex bison pkg-config libtirpc-dev && \
    git clone --depth 1 https://github.com/unfs3/unfs3.git /tmp/unfs3 && \
    cd /tmp/unfs3 && \
    ./bootstrap && \
    ./configure && \
    make && \
    make install && \
    cd / && rm -rf /tmp/unfs3 && \
    apt-get purge -y git build-essential autoconf automake libtool flex bison pkg-config libtirpc-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Bootloader PXE (modo BIOS legacy, el más compatible con QEMU/VMs/HW real)
RUN mkdir -p /srv/tftp/pxelinux.cfg /srv/tftp/ltsp && \
    cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/ && \
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/

# Kernel + initrd construidos en la etapa builder
COPY --from=builder /artifacts/vmlinuz   /srv/tftp/ltsp/vmlinuz
COPY --from=builder /artifacts/initrd.img /srv/tftp/ltsp/initrd.img
RUN chmod -R a+r /srv/tftp

# Rootfs que se exporta por NFS
# Rootfs que se exporta por NFS: se deja empacado como .tar; el
# entrypoint lo extrae en /srv/ltsp/rootfs, que en docker-compose
# se monta como volumen (no puede vivir en la capa overlay del
# contenedor porque esa capa no soporta exportación NFS).
COPY --from=builder /artifacts/rootfs.tar /opt/ltsp-rootfs.tar

COPY pxelinux.cfg.default /srv/tftp/pxelinux.cfg/default
COPY exports /etc/exports
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 69/udp 111/tcp 111/udp 2049/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
