#!/usr/bin/env python3
"""Boot-tests KickflipOS in QEMU. Run after ./build.sh:  python3 tests/smoke_test.py

1. Boots the kernel + initramfs on a serial console with a blank "locker" disk,
   runs some commands, saves a high score, and powers off with `bail`.
2. Boots again on the same disk, checks the high score survived, and plays
   Street Cruise until the first crash.
3. Boots the real ISO through GRUB on a virtual screen and checks the skate
   palette appeared (proof that the kernel, init and skatecolors all ran).
   Saves the final frame as build/screenshot.png.

Uses only the Python standard library.
"""
import os, re, select, socket, struct, subprocess, sys, tempfile, time, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
KERNEL = os.path.join(BUILD, "iso", "boot", "vmlinuz")
INITRD = os.path.join(BUILD, "initramfs.gz")
ISO = os.path.join(ROOT, "kickflipos.iso")
PROMPT = "=o==o="
ACCEL = ["-accel", "kvm", "-accel", "tcg"] if os.access("/dev/kvm", os.W_OK) else ["-accel", "tcg"]
ANSI = re.compile(r"\x1b(\[[0-9;?]*[A-Za-z]|\][^\x1b]{0,8})")

failures = []


def check(ok, what):
    print(("  PASS  " if ok else "  FAIL  ") + what)
    if not ok:
        failures.append(what)


class SerialVM:
    def __init__(self, disk):
        self.p = subprocess.Popen(
            ["qemu-system-x86_64", *ACCEL, "-m", "256", "-nographic", "-no-reboot",
             "-kernel", KERNEL, "-initrd", INITRD, "-append", "console=ttyS0 quiet",
             "-drive", f"file={disk},format=raw,if=ide"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.buf = ""

    def read_until(self, text, timeout):
        end = time.time() + timeout
        while time.time() < end:
            if text in ANSI.sub("", self.buf):
                return True
            r, _, _ = select.select([self.p.stdout], [], [], 0.5)
            if r:
                chunk = os.read(self.p.stdout.fileno(), 4096)
                if not chunk:
                    break
                self.buf += chunk.decode("utf-8", "replace")
        return text in ANSI.sub("", self.buf)

    def run(self, cmd, timeout=30):
        """Type a command and return its output (up to the next prompt)."""
        self.buf = ""
        self.p.stdin.write((cmd + "\n").encode())
        self.p.stdin.flush()
        self.read_until(PROMPT, timeout)
        return ANSI.sub("", self.buf)

    def wait_exit(self, timeout):
        try:
            self.p.wait(timeout)
            return True
        except subprocess.TimeoutExpired:
            self.p.kill()
            return False


def png(path, w, h, rgb):
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def read_ppm(path):
    data = open(path, "rb").read()
    parts = data.split(maxsplit=4)
    w, h = int(parts[1]), int(parts[2])
    return w, h, parts[4][-w * h * 3:]


def serial_tests():
    disk = tempfile.NamedTemporaryFile(suffix=".img", delete=False).name
    os.truncate(disk, 32 * 1024 * 1024)  # blank disk, like a fresh VirtualBox .vdi
    try:
        print("Boot 1: blank locker disk")
        vm = SerialVM(disk)
        booted = vm.read_until(PROMPT, 180)
        out = ANSI.sub("", vm.buf)
        check(booted, "boots to the KickflipOS prompt")
        check("New locker set up" in out, "formats a blank disk as the locker")
        check("K I C K F L I P" in out, "shows the welcome screen")
        check("You go for a" in vm.run("trick"), "trick runs")
        check("Ollie:" in vm.run("ollie"), "ollie runs")
        check('"' in vm.run("stoke"), "stoke runs")
        check("Locker open" in vm.run("locker"), "locker reports it is open")
        vm.run("echo 4242 > /root/.skate_highscore")
        vm.p.stdin.write(b"bail\n"); vm.p.stdin.flush()
        check(vm.wait_exit(60), "bail powers off the VM")

        print("Boot 2: same disk")
        vm = SerialVM(disk)
        booted = vm.read_until(PROMPT, 180)
        check(booted and "Locker open" in ANSI.sub("", vm.buf), "reopens the existing locker")
        check("4242" in vm.run("cat /root/.skate_highscore"), "high score survived the reboot")
        send = lambda b: (setattr(vm, "buf", ""), vm.p.stdin.write(b), vm.p.stdin.flush())
        send(b"cruise\n")
        check(vm.read_until("drop in", 30), "cruise shows its title screen")
        send(b" ")
        check(vm.read_until("go again", 180), "cruise runs in real time until the first cone hits")
        send(b"q")
        check(vm.read_until(PROMPT, 30), "cruise quits back to the shell")
        check(vm.run("cat /root/.cruise_highscore").strip() != "", "cruise saves a best score to the locker")
        vm.p.stdin.write(b"bail\n"); vm.p.stdin.flush()
        vm.wait_exit(60)
    finally:
        os.unlink(disk)


def iso_test():
    print("Boot 3: the ISO through GRUB, on a virtual screen")
    tmp = tempfile.mkdtemp()
    sock = os.path.join(tmp, "monitor.sock")
    p = subprocess.Popen(["qemu-system-x86_64", *ACCEL, "-m", "256", "-cdrom", ISO,
                          "-display", "none", "-vga", "std",
                          "-monitor", f"unix:{sock},server,nowait"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            if os.path.exists(sock):
                break
            time.sleep(0.2)
        mon = socket.socket(socket.AF_UNIX)
        mon.connect(sock)
        ppm = os.path.join(tmp, "screen.ppm")
        asphalt = bytes.fromhex("15151a")
        share, w, h, rgb = 0.0, 0, 0, b""
        end = time.time() + 180
        while time.time() < end:
            time.sleep(3)
            mon.sendall(f"screendump {ppm}\n".encode())
            time.sleep(1)
            if not os.path.exists(ppm):
                continue
            w, h, rgb = read_ppm(ppm)
            px = [rgb[i:i + 3] for i in range(0, len(rgb), 3 * 97)]  # sample pixels
            share = sum(1 for c in px if c == asphalt) / max(len(px), 1)
            if share > 0.5:
                time.sleep(6)  # let the welcome screen finish drawing
                mon.sendall(f"screendump {ppm}\n".encode())
                time.sleep(1)
                w, h, rgb = read_ppm(ppm)
                break
        check(share > 0.5, f"GRUB boots it and the skate palette is on screen ({share:.0%} asphalt)")
        if rgb:
            png(os.path.join(BUILD, "screenshot.png"), w, h, rgb)
            print("  Saved build/screenshot.png")
    finally:
        p.kill()


if __name__ == "__main__":
    for f in (KERNEL, INITRD, ISO):
        if not os.path.exists(f):
            sys.exit(f"Missing {f}. Run ./build.sh first.")
    serial_tests()
    iso_test()
    print()
    if failures:
        sys.exit(f"{len(failures)} check(s) failed")
    print("All checks passed. Clean landing.")
