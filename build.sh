#!/bin/sh
# Builds kickflipos.iso. Run from anywhere: ./build.sh
set -e
cd "$(dirname "$0")"

# Folders git doesn't track (they're empty)
mkdir -p rootfs/proc rootfs/sys rootfs/dev rootfs/tmp rootfs/root \
         rootfs/usr/share/consolefonts iso/boot/grub

# Borrow parts from the host if missing
[ -f rootfs/bin/busybox ] || cp /bin/busybox rootfs/bin/
[ -f rootfs/usr/share/consolefonts/kickflip.psf ] || \
  zcat /usr/share/consolefonts/Lat15-TerminusBold16.psf.gz > rootfs/usr/share/consolefonts/kickflip.psf
# setfont (BusyBox on Ubuntu doesn't have it) plus the libraries it needs
if [ ! -f rootfs/usr/bin/setfont ]; then
  mkdir -p rootfs/usr/bin
  cp "$(command -v setfont)" rootfs/usr/bin/setfont
  for lib in $(ldd "$(command -v setfont)" | grep -o '/[^ ]*'); do
    mkdir -p "rootfs$(dirname "$lib")"
    cp -L "$lib" "rootfs$lib"
  done
fi
if [ ! -f iso/boot/vmlinuz ]; then
  echo "Copying your kernel (needs sudo)..."
  sudo cp "/boot/vmlinuz-$(uname -r)" iso/boot/vmlinuz
  sudo chown "$USER" iso/boot/vmlinuz
fi

# Pack everything into a bootable ISO
(cd rootfs && find . | cpio -o -H newc --quiet | gzip) > iso/boot/initramfs.gz
grub-mkrescue -o kickflipos.iso iso 2>/dev/null
echo "Built kickflipos.iso - time to drop in"
