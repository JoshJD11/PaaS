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

RUN apt-get update && apt-get install -y --no-install-recommends \
        tftpd-hpa \
        nfs-kernel-server \
        rpcbind \
        pxelinux \
        syslinux-common \
        net-tools && \
    rm -rf /var/lib/apt/lists/*

# Bootloader PXE (modo BIOS legacy, el más compatible con QEMU/VMs/HW real)
RUN mkdir -p /srv/tftp/pxelinux.cfg /srv/tftp/ltsp && \
    cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/ && \
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/

# Kernel + initrd construidos en la etapa builder
COPY --from=builder /artifacts/vmlinuz   /srv/tftp/ltsp/vmlinuz
COPY --from=builder /artifacts/initrd.img /srv/tftp/ltsp/initrd.img

# Rootfs que se exporta por NFS
RUN mkdir -p /srv/ltsp/rootfs
COPY --from=builder /artifacts/rootfs.tar /tmp/rootfs.tar
RUN tar -C /srv/ltsp/rootfs -xf /tmp/rootfs.tar && rm /tmp/rootfs.tar

COPY pxelinux.cfg.default /srv/tftp/pxelinux.cfg/default
COPY exports /etc/exports
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 69/udp 111/tcp 111/udp 2049/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
