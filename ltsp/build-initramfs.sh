#!/bin/bash
set -e

KVER=$(ls /lib/modules | head -n1)
echo "==> Kernel detectado: $KVER"

WORK=/tmp/initramfs
mkdir -p "$WORK"/{bin,sbin,etc,proc,sys,dev,newroot,usr/share/udhcpc,lib/modules}

cp /bin/busybox "$WORK"/bin/busybox
for applet in sh mount umount switch_root modprobe depmod insmod lsmod \
              mdev udhcpc cat ls mkdir ifconfig ip route sleep; do
    ln -sf busybox "$WORK"/bin/$applet
done
for applet in modprobe depmod insmod switch_root; do
    ln -sf ../bin/busybox "$WORK"/sbin/$applet
done

echo "==> Copiando arbol completo de modulos del kernel..."
cp -a /lib/modules/$KVER "$WORK"/lib/modules/
depmod -b "$WORK" "$KVER" 2>/dev/null || true

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

cat > "$WORK"/init << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null
/bin/busybox mdev -s

export PATH=/bin:/sbin

echo "PaaS.net Thin Client: cargando modulos de red/NFS (modprobe)..."
for m in virtio_net e1000 e1000e 8139cp r8169; do
    /bin/busybox modprobe "$m" 2>/dev/null
done
/bin/busybox modprobe nfsv3 2>/dev/null || /bin/busybox modprobe nfs 2>/dev/null

echo "PaaS.net Thin Client: levantando interfaz de red..."
/bin/busybox ifconfig eth0 up
/bin/busybox sleep 3

echo "PaaS.net Thin Client: solicitando IP por DHCP..."
/bin/busybox udhcpc -i eth0 -s /usr/share/udhcpc/simple.script -n -t 8 -q

echo "PaaS.net Thin Client: montando raiz por NFS (ltsp_server:/srv/ltsp/rootfs)..."
/bin/busybox mount -t nfs -o nolock,vers=3,port=2049,mountport=2049,proto=tcp \
    172.30.0.11:/srv/ltsp/rootfs /newroot

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

echo "==> Listo. Tamano del initrd:"
ls -lh /artifacts/initrd.img
