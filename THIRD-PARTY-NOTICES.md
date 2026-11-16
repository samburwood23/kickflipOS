# Third-party software in KickflipOS

`build.sh` builds the KickflipOS ISO from other people's software. This file lists what's in it
and where the source comes from.

| Component | Version | Licence | Source |
| --- | --- | --- | --- |
| Linux kernel | see `versions.sh` | GPL-2.0 | Downloaded by `build.sh` from the pinned commit in `versions.sh`. Upstream: [kernel.org](https://www.kernel.org) |
| BusyBox | see `versions.sh` | GPL-2.0 | Downloaded by `build.sh` from the pinned commit in `versions.sh`. Upstream: [busybox.net](https://busybox.net) |
| GRUB (boot loader) | your system's `grub-pc-bin` | GPL-3.0 | Your distribution's `grub2` source package |
| Terminus console font | your system's `console-setup-linux` | SIL Open Font License 1.1 | [terminus-font.sourceforge.net](https://terminus-font.sourceforge.net) |

`build.sh` and `config/` are the complete scripts used to configure and build the kernel and
BusyBox. If you share a built ISO with anyone, the GPL requires you to make the matching
source available to them too.
