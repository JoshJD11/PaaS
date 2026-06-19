#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Construye el filesystem raíz que el Thin Client monta por NFS
# una vez que el initramfs hace switch_root. Es deliberadamente
# mínimo (BusyBox) para que el build sea rápido y 100% reproducible;
# lo importante para el curso de Redes es la cadena de protocolos
# (PXE/DHCP/TFTP/NFS), no si hay un escritorio gráfico.
# ─────────────────────────────────────────────────────────────
set -e

ROOTFS=/srv/ltsp/rootfs
mkdir -p "$ROOTFS"/{bin,etc,proc,sys,dev,tmp,root}

cp /bin/busybox "$ROOTFS"/bin/busybox
for applet in sh ls cat mount umount echo ifconfig ps mkdir touch reboot poweroff; do
    ln -sf busybox "$ROOTFS"/bin/$applet
done

cat > "$ROOTFS"/init << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc 2>/dev/null
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null
clear
echo "=================================================="
echo "  PaaS.net - Thin Client Server (estilo LTSP)"
echo "  Este sistema arranco 100% por red:"
echo "  DHCP -> PXE -> TFTP (kernel/initrd) -> NFS (root)"
echo "  No se utilizo ningun disco local en este cliente."
echo "=================================================="
exec /bin/busybox sh
EOF
chmod +x "$ROOTFS"/init

mkdir -p /artifacts
tar -C "$ROOTFS" -cf /artifacts/rootfs.tar .
echo "==> rootfs empaquetado en /artifacts/rootfs.tar"
