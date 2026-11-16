# Third-party software in KickflipOS

The KickflipOS ISO contains software written by other people. This file explains what's in
it and where to get the source.

| Component | Version | Licence | Where the source is |
| --- | --- | --- | --- |
| Linux kernel | see `versions.sh` | GPL-2.0 | Attached to every [GitHub Release](https://github.com/samburwood23/kickflipOS/releases) as `linux-*.tar.xz`, with the exact build config as `kernel.config`. Upstream: [kernel.org](https://www.kernel.org) |
| BusyBox | see `versions.sh` | GPL-2.0 | Attached to every release as `busybox-*.tar.bz2`, with `busybox.config`. Upstream: [busybox.net](https://busybox.net) |
| GRUB (boot loader) | Ubuntu 24.04's `grub-pc-bin` | GPL-3.0 | Ubuntu's `grub2` source package: [launchpad.net/ubuntu/+source/grub2](https://launchpad.net/ubuntu/+source/grub2) |
| Terminus console font | Ubuntu 24.04's `console-setup-linux` | SIL Open Font License 1.1 | [terminus-font.sourceforge.net](https://terminus-font.sourceforge.net) |

`build.sh` and `config/` are the complete scripts used to configure and build the kernel and
BusyBox from that source.

Everything else in this repository (the scripts in `rootfs/`, `build.sh`, the tests and the
workflow) is the KickflipOS project itself.
