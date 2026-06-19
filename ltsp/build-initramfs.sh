#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Construye el initrd que el Thin Client descarga por TFTP.
# Es un initramfs mínimo (BusyBox estático) cuyo único trabajo
# es: pedir IP por DHCP, cargar los módulos de NFS/red, montar
# la raíz real por NFS y entregarle el control (switch_root).
#
# No usamos un Ubuntu/Xfce completo aquí porque instalar un
# entorno gráfico completo dentro de un chroot anidado en un
# "docker build" es poco confiable (los postinst de paquetes
# de escritorio asumen systemd/udev corriendo, cosa que no
# existe durante el build). Con BusyBox el resultado es 100%
# reproducible y de todas formas se demuestra exactamente el
# mismo protocolo de arranque que usa LTSP: PXE -> TFTP ->
# kernel/initrd -> DHCP -> NFS root.
# ─────────────────────────────────────────────────────────────
set -e

KVER=$(ls /lib/modules | head -n1)
echo "==> Kernel detectado: $KVER"

WORK=/tmp/initramfs
mkdir -p "$WORK"/{bin,etc,proc,sys,dev,newroot,lib/modules,usr/share/udhcpc}

# BusyBox estático provee sh, mount, insmod, udhcpc, switch_root, etc.
cp /bin/busybox "$WORK"/bin/busybox
for applet in sh mount umount switch_root insmod mdev udhcpc cat ls mkdir ifconfig route; do
    ln -sf busybox "$WORK"/bin/$applet
done

# Script que udhcpc invoca cuando recibe una IP
cat > "$WORK"/usr/share/udhcpc/simple.script << 'EOF'
#!/bin/busybox sh
[ -z "$1" ] && exit 1
case "$1" in
    bound|renew)
        /bin/busybox ifconfig "$interface" "$ip" netmask "$subnet" up
        [ -n "$router" ] && /bin/busybox route add default gw "$router"
        ;;
esac
EOF
chmod +x "$WORK"/usr/share/udhcpc/simple.script

# Pila de módulos necesaria: cliente NFS + drivers de red comunes
# (cubre tarjetas reales y las que emulan QEMU/VirtualBox/VMware)
MODULES="sunrpc lockd grace nfs_acl nfsv3 nfs virtio_net e1000 8139too r8169"
for m in $MODULES; do
    f=$(find /lib/modules/$KVER -name "${m}.ko*" 2>/dev/null | head -n1)
    if [ -n "$f" ]; then
        case "$f" in
            *.zst) zstd -d "$f" -o "$WORK/lib/modules/${m}.ko" -f 2>/dev/null || true ;;
            *.gz)  gzip -dc "$f" > "$WORK/lib/modules/${m}.ko" ;;
            *)     cp "$f" "$WORK/lib/modules/${m}.ko" ;;
        esac
        echo "    módulo incluido: $m"
    else
        echo "    aviso: no se encontró $m (puede venir integrado en el kernel)"
    fi
done

# /init = primer proceso que el kernel ejecuta al arrancar
cat > "$WORK"/init << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mdev -s

echo "PaaS.net Thin Client: cargando modulos de red/NFS..."
for m in sunrpc lockd grace nfs_acl nfsv3 nfs virtio_net e1000 8139too r8169; do
    /bin/busybox insmod /lib/modules/$m.ko 2>/dev/null
done

echo "PaaS.net Thin Client: solicitando IP por DHCP..."
/bin/busybox udhcpc -i eth0 -s /usr/share/udhcpc/simple.script -n -q

echo "PaaS.net Thin Client: montando raiz por NFS (ltsp_server:/srv/ltsp/rootfs)..."
/bin/busybox mount -t nfs -o nolock,vers=3 172.30.0.11:/srv/ltsp/rootfs /newroot

if [ ! -x /newroot/init ]; then
    echo "ERROR: no se pudo montar el filesystem raiz por NFS. Shell de emergencia:"
    exec /bin/busybox sh
fi

exec /bin/busybox switch_root /newroot /init
EOF
chmod +x "$WORK"/init

mkdir -p /artifacts
( cd "$WORK" && find . | cpio -o -H newc 2>/dev/null | gzip -9 > /artifacts/initrd.img )
cp /boot/vmlinuz-$KVER /artifacts/vmlinuz

echo "==> Listo: /artifacts/vmlinuz y /artifacts/initrd.img"
