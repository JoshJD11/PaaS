FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        linux-image-virtual \
        busybox-static \
        kmod zstd cpio gzip && \
    rm -rf /var/lib/apt/lists/*

COPY build-initramfs.sh /usr/local/bin/build-initramfs.sh
RUN chmod +x /usr/local/bin/build-initramfs.sh && \
    /usr/local/bin/build-initramfs.sh

FROM ubuntu:22.04 AS rootfs
ENV DEBIAN_FRONTEND=noninteractive

COPY build-rootfs.sh /usr/local/bin/build-rootfs.sh
RUN chmod +x /usr/local/bin/build-rootfs.sh && \
    /usr/local/bin/build-rootfs.sh

FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

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

RUN mkdir -p /srv/tftp/pxelinux.cfg /srv/tftp/ltsp && \
    cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/ && \
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/

COPY --from=builder /artifacts/vmlinuz   /srv/tftp/ltsp/vmlinuz
COPY --from=builder /artifacts/initrd.img /srv/tftp/ltsp/initrd.img
RUN chmod -R a+r /srv/tftp

COPY --from=rootfs /artifacts/rootfs.tar /opt/ltsp-rootfs.tar

COPY pxelinux.cfg.default /srv/tftp/pxelinux.cfg/default
COPY exports /etc/exports
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 69/udp 111/tcp 111/udp 2049/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
