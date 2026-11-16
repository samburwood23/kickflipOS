# KickflipOS

A tiny skateboard-themed Linux OS that runs in VirtualBox. It's the Linux kernel, BusyBox and a
handful of scripts with attitude. Your guide is **Ollie**, a skater who lives in the terminal.

## Build it (on Ubuntu 24.04)

**1. Install the build tools** (one time only):

    sudo apt install git busybox-static cpio grub-pc-bin xorriso mtools kbd console-setup-linux

**2. Get the code** (one time only):

    cd ~
    git clone https://github.com/samburwood23/kickflipOS.git
    cd kickflipOS

**3. Build the ISO:**

    ./build.sh

The first build asks for your password once, so it can copy your Ubuntu kernel. When it prints
`Built kickflipos.iso - time to drop in`, you have a file called `kickflipos.iso` in the folder.

## Boot it in VirtualBox

1. Open VirtualBox and click **New**.
2. **Name:** `KickflipOS`. **ISO Image:** leave empty. **Type:** `Linux`. **Version:** `Other Linux (64-bit)`.
3. **Memory:** `512 MB`. **CPUs:** `1`.
4. **Hard Disk:** choose **Do Not Add a Virtual Hard Disk**, then click **Finish** (ignore the warning).
5. Select the VM, then go to **Settings > Storage**. Click the empty CD icon under *Controller: IDE*. On the right,
   click the small CD icon > **Choose a disk file...**, then pick `~/kickflipOS/kickflipos.iso`.
6. Click **OK**, then **Start**.

At the yellow menu, press Enter on **KickflipOS - drop in**. If the screen stays black or looks broken,
restart the VM and choose **old school (text mode)** instead.

## Commands inside KickflipOS

| Command | What it does |
|---|---|
| `skate` | Play **Street Session**, the skate game |
| `hello` | Show the welcome screen |
| `ollie` | Ollie says something |
| `trick` (or `grind`) | Try a random trick: land it or bail |
| `stoke` | Random skate wisdom |
| `session` | How you're feeling, based on uptime |
| `skatecolors` | Reapply the skate colour palette |
| `cls` | Clear the screen and show the welcome screen |
| `ll` | List all files in detail |
| `bail` | Power off |

You also get ~300 standard commands from BusyBox (`ls`, `cd`, `cat`, `vi`, `top`, `ps`...). Type
`busybox --list` to see them all.

### Street Session rules

Each game is 3 runs at random spots. On each run, chain tricks to build a combo. Every extra trick
is harder to land, and if you bail, you lose the whole run. Roll away (`r`) to bank your points.
Your score is combo points x number of tricks x spot multiplier. High scores reset on reboot (for now).

## Make changes

| To change... | Edit |
|---|---|
| Boot messages | `rootfs/init` |
| Welcome screen | `rootfs/bin/hello` |
| Ollie's lines, tricks, wisdom | `rootfs/etc/ollie.txt`, `tricks.txt`, `stoke.txt` (one per line) |
| Colours | `rootfs/bin/skatecolors` (hex values) |
| Prompt and aliases | `rootfs/etc/profile` |
| The game | `rootfs/bin/skate` |
| Boot menu | `iso/boot/grub/grub.cfg` |

After editing, run `./build.sh` again and restart the VM. To get changes made elsewhere (for example by Claude):

    git pull
    ./build.sh

## How it works

`build.sh` copies three things from your Ubuntu install: the kernel, a static BusyBox and the
`setfont` tool with its libraries. It packs them with everything in `rootfs/` into a compressed
archive (the *initramfs*), then wraps that and the GRUB boot menu into a bootable ISO. When the VM
boots, the kernel unpacks the initramfs into RAM and runs `rootfs/init`, which is the start of
KickflipOS. Everything runs from RAM, so nothing is saved between boots.
