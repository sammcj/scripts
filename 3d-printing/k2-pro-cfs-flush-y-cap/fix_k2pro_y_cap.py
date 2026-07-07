#!/usr/bin/env python3
"""Fix the Creality K2 Pro CFS-flush Y-cap crash after a firmware update.

Problem: Creality firmware updates revert printer_data/config, resetting
`variable_max_y_position` (in the `[gcode_macro PRINTER_PARAM]` section) to 302.0.
On this unit that value sits right at the rear edge of the CFS filament-flush
region, so master-server's flush move (observed ~Y302.2-303.1) overshoots the
Klipper Y limit by a fraction and the print aborts at start with:
    {"code":"key586","msg":"Move out of range: <x> <y> <z> [<e>]"}
Klipper's stepper.py overrides `stepper_y.position_max` with this macro variable,
so it (not the 332 in `[stepper_y]`) is the value that actually caps Y. Raising it
to TARGET_Y gives the flush clearance; the box arm physically reaches Y=329 during
normal CFS ops, so TARGET_Y stays well within the mechanical envelope.

Idempotent: only raises the value when it is below TARGET_Y, backs up the config
first, then FIRMWARE_RESTARTs and verifies the live Y cap via the Klipper socket.

Run on the printer after a firmware update:
    python3 fix_k2pro_y_cap.py          # apply + restart + verify
    python3 fix_k2pro_y_cap.py --dry-run
    python3 fix_k2pro_y_cap.py --target 308
    python3 fix_k2pro_y_cap.py --no-restart   # edit only, apply later
"""
import argparse
import json
import re
import shutil
import socket
import sys
import time

CONFIG = "/mnt/UDISK/printer_data/config/gcode_macro.cfg"
SOCK = "/tmp/klippy_uds"
VAR = "variable_max_y_position"
DEFAULT_TARGET = 306.0  # ~3mm over the observed flush ceiling (~303.06); safely under the 329 box travel
LINE_RE = re.compile(r"^(\s*)" + re.escape(VAR) + r"\s*:\s*([0-9.]+)\s*$", re.MULTILINE)


def sock_call(method, params=None, timeout=30):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(SOCK)
    s.sendall(json.dumps({"id": 1, "method": method, "params": params or {}}).encode() + b"\x03")
    buf = b""
    while b"\x03" not in buf:
        d = s.recv(4096)
        if not d:
            break
        buf += d
    s.close()
    return json.loads(buf.split(b"\x03")[0].decode())


def live_y_cap():
    r = sock_call("objects/query", {"objects": {"toolhead": ["axis_maximum"]}})
    return r["result"]["status"]["toolhead"]["axis_maximum"][1]


def patch_config(target, dry_run):
    with open(CONFIG) as f:
        text = f.read()
    m = LINE_RE.search(text)
    if not m:
        sys.exit("ERROR: %s not found in %s - not the expected K2 Pro config" % (VAR, CONFIG))
    current = float(m.group(2))
    if current >= target:
        print("Config already at %.1f (>= target %.1f) - no change." % (current, target))
        return False
    print("Config %s: %.1f -> %.1f" % (VAR, current, target))
    if dry_run:
        print("(dry-run: config not written)")
        return False
    backup = "%s.ycap.bak-%s" % (CONFIG, time.strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(CONFIG, backup)
    print("Backup: %s" % backup)
    new_text = text[:m.start()] + "%s%s: %.1f" % (m.group(1), VAR, target) + text[m.end():]
    with open(CONFIG, "w") as f:
        f.write(new_text)
    return True


def restart_and_verify(target):
    print("FIRMWARE_RESTART...")
    sock_call("gcode/script", {"script": "FIRMWARE_RESTART"})
    for _ in range(20):  # socket refuses connections while klippy reloads
        time.sleep(1)
        try:
            cap = live_y_cap()
        except (OSError, KeyError, ValueError):
            continue
        if cap >= target:
            print("Verified: live axis_maximum.y = %.1f" % cap)
            return True
        print("Live cap %.1f still below %.1f, waiting..." % (cap, target))
    print("WARNING: could not confirm live cap >= %.1f within timeout." % target)
    return False


def main():
    ap = argparse.ArgumentParser(description="Fix the K2 Pro CFS-flush Y-cap crash.")
    ap.add_argument("--target", type=float, default=DEFAULT_TARGET, help="Y cap to raise to (default %.1f)" % DEFAULT_TARGET)
    ap.add_argument("--dry-run", action="store_true", help="show the change without writing")
    ap.add_argument("--no-restart", action="store_true", help="edit config only; skip FIRMWARE_RESTART")
    args = ap.parse_args()

    if not (303.0 < args.target < 329.0):
        sys.exit("ERROR: --target %.1f out of safe range (303, 329)" % args.target)

    changed = patch_config(args.target, args.dry_run)
    if args.dry_run or args.no_restart:
        if changed:
            print("Config written. Run FIRMWARE_RESTART (or reprint after a restart) to apply.")
        return
    if not changed:
        # confirm the live cap is already good even when the file needed no edit
        try:
            cap = live_y_cap()
            print("Live axis_maximum.y = %.1f%s" % (cap, "" if cap >= args.target else " (below target - run FIRMWARE_RESTART)"))
        except OSError:
            print("Klipper socket unavailable; config already satisfies target.")
        return
    restart_and_verify(args.target)


if __name__ == "__main__":
    main()
