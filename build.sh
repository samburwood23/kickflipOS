#!/bin/sh
# Builds kickflipos.iso from source: the Linux kernel, BusyBox and everything in rootfs/.
# The first run downloads and compiles the kernel (a few minutes). Later runs take seconds.
set -e
cd "$(dirname "$0")"
. ./versions.sh

B=build
JOBS=$(nproc 2>/dev/null || echo 2)
K=$B/linux-$KERNEL_VERSION
BB=$B/busybox-$BUSYBOX_VERSION
FONT=/usr/share/consolefonts/Lat15-TerminusBold16.psf.gz

# --- Check the tools are installed -------------------------------------------
missing=""
for cmd in git make gcc flex bison bc cpio gzip xz grub-mkrescue xorriso mformat; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
[ -f "$FONT" ] || missing="$missing console-font"
[ -f /usr/include/libelf.h ] || missing="$missing libelf-dev"
if [ -n "$missing" ]; then
  echo "Missing:$missing" >&2
  echo "Install everything with:" >&2
  echo "  sudo apt install git build-essential flex bison bc libelf-dev libssl-dev cpio xz-utils grub-pc-bin xorriso mtools console-setup-linux" >&2
  exit 1
fi

# --- Remove files the old (pre-v1) build.sh copied into the source tree ------
rm -f iso/boot/vmlinuz iso/boot/initramfs.gz rootfs/bin/busybox \
      rootfs/usr/bin/setfont rootfs/usr/share/consolefonts/kickflip.psf
rm -rf rootfs/lib rootfs/lib64 rootfs/usr/lib

mkdir -p $B

# --- Helpers ------------------------------------------------------------------
fetch() { # name repo tag commit dir
  if [ ! -d "$5/.git" ]; then
    echo "==> Downloading $1 source ($3)"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$3" "$2" "$5"
  fi
  got=$(git -C "$5" rev-parse HEAD)
  if [ "$got" != "$4" ]; then
    echo "$1 source in $5 is commit $got, expected $4. Delete $5 and rerun." >&2
    exit 1
  fi
}

apply_fragment() { # scripts/config .config fragment
  grep -E '^(CONFIG_|# CONFIG_)' "$3" | while IFS= read -r line; do
    case "$line" in
      "# CONFIG_"*) name=${line#\# }; "$1" --file "$2" --disable "${name%% *}" ;;
      *=y)          "$1" --file "$2" --enable "${line%%=*}" ;;
    esac
  done
}

check_fragment() { # .config fragment
  grep -E '^(CONFIG_|# CONFIG_)' "$2" | while IFS= read -r line; do
    case "$line" in
      "# CONFIG_"*) name=${line#\# }; name=${name%% *}
                    if grep -q "^$name=" "$1"; then echo "  $name should be off" >&2; exit 1; fi ;;
      *)            if ! grep -qx "$line" "$1"; then echo "  $line didn't stick" >&2; exit 1; fi ;;
    esac
  done || { echo "Config check failed for $1 (a dependency is probably missing)" >&2; exit 1; }
}

stamp() { cat "$@" | sha256sum | cut -c1-16; }

# --- Kernel -------------------------------------------------------------------
fetch Linux "$KERNEL_REPO" "$KERNEL_TAG" "$KERNEL_COMMIT" "$K"
s=$(stamp versions.sh config/kernel.fragment)
if [ ! -f "$K/arch/x86/boot/bzImage" ] || [ "$(cat "$K/.kickflip-stamp" 2>/dev/null)" != "$s" ]; then
  echo "==> Building Linux $KERNEL_VERSION (a few minutes the first time)"
  make -C "$K" -s tinyconfig
  apply_fragment "$K/scripts/config" "$K/.config" config/kernel.fragment
  make -C "$K" -s olddefconfig
  check_fragment "$K/.config" config/kernel.fragment
  make -C "$K" -s -j"$JOBS" bzImage
  echo "$s" > "$K/.kickflip-stamp"
fi

# --- BusyBox ------------------------------------------------------------------
fetch BusyBox "$BUSYBOX_REPO" "$BUSYBOX_TAG" "$BUSYBOX_COMMIT" "$BB"
s=$(stamp versions.sh config/busybox.fragment)
if [ ! -f "$BB/busybox" ] || [ "$(cat "$BB/.kickflip-stamp" 2>/dev/null)" != "$s" ]; then
  echo "==> Building BusyBox $BUSYBOX_VERSION"
  make -C "$BB" -s defconfig >/dev/null
  apply_fragment "$K/scripts/config" "$BB/.config" config/busybox.fragment
  yes "" | make -C "$BB" -s oldconfig >/dev/null
  check_fragment "$BB/.config" config/busybox.fragment
  make -C "$BB" -s -j"$JOBS" busybox 2>"$B/busybox-build.log" || { cat "$B/busybox-build.log"; exit 1; }
  echo "$s" > "$BB/.kickflip-stamp"
fi

# --- Root filesystem -> initramfs ---------------------------------------------
echo "==> Packing the root filesystem"
R=$B/rootfs
rm -rf "$R"
cp -a rootfs "$R"
mkdir -p "$R/proc" "$R/sys" "$R/dev" "$R/tmp" "$R/root" "$R/usr/share/consolefonts"
cp "$BB/busybox" "$R/bin/busybox"
zcat "$FONT" > "$R/usr/share/consolefonts/kickflip.psf"
(cd "$R" && find . | cpio -o -H newc -R 0:0 --quiet | gzip -9) > "$B/initramfs.gz"

# --- Bootable ISO -------------------------------------------------------------
echo "==> Making the ISO"
I=$B/iso
rm -rf "$I"
mkdir -p "$I/boot/grub"
cp iso/boot/grub/grub.cfg "$I/boot/grub/"
cp "$K/arch/x86/boot/bzImage" "$I/boot/vmlinuz"
cp "$B/initramfs.gz" "$I/boot/initramfs.gz"
grub-mkrescue -o kickflipos.iso "$I" 2>"$B/grub-mkrescue.log" || { cat "$B/grub-mkrescue.log"; exit 1; }

echo
echo "Built kickflipos.iso ($(du -h kickflipos.iso | cut -f1)) - time to drop in"
echo "  kernel:    $(du -h "$I/boot/vmlinuz" | cut -f1)  (Linux $KERNEL_VERSION)"
echo "  initramfs: $(du -h "$B/initramfs.gz" | cut -f1)  (BusyBox $BUSYBOX_VERSION + rootfs/)"
