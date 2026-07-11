#!/usr/bin/env python3
"""Query and control Klipper over its unix API socket.

Must run ON the printer - the socket is local to it. Klipper's API takes JSON
requests terminated by a 0x03 byte and replies the same way.

    python3 kq.py state          # print state - check this before touching anything
    python3 kq.py limits         # live axis min/max + homed axes
    python3 kq.py query toolhead:position,homed_axes extruder:temperature
    python3 kq.py cfg            # list config section names
    python3 kq.py cfg stepper_y  # dump a section
    python3 kq.py gcode "M115"
    python3 kq.py restart        # FIRMWARE_RESTART; refuses while a print is active

Nothing here is model-specific beyond the default socket path, though it is used
on a Creality K2 Pro. Targets the printer's Python 3.9.
"""
import argparse
import json
import socket
import sys
import time

DEFAULT_SOCKET = "/tmp/klippy_uds"
EOT = b"\x03"
ACTIVE_STATES = {"printing", "paused"}


class KlipperError(RuntimeError):
    pass


def call(method, params=None, sock_path=DEFAULT_SOCKET, timeout=30):
    """Send one request and return its result payload."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(sock_path)
    except OSError as exc:
        raise KlipperError("cannot connect to %s: %s" % (sock_path, exc)) from exc
    try:
        sock.sendall(json.dumps({"id": 1, "method": method, "params": params or {}}).encode() + EOT)
        buf = b""
        while EOT not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                raise KlipperError("socket closed before a complete response")
            buf += chunk
    except socket.timeout as exc:
        raise KlipperError("timed out waiting for Klipper") from exc
    finally:
        sock.close()
    resp = json.loads(buf.split(EOT)[0].decode())
    if "error" in resp:
        raise KlipperError(json.dumps(resp["error"]))
    return resp.get("result", {})


def query(objects, sock_path):
    return call("objects/query", {"objects": objects}, sock_path).get("status", {})


def parse_objects(specs):
    """"toolhead:position,homed_axes" -> {"toolhead": ["position", "homed_axes"]}"""
    objects = {}
    for spec in specs:
        name, _, fields = spec.partition(":")
        objects[name] = fields.split(",") if fields else None
    return objects


def print_is_active(sock_path):
    state = query({"print_stats": ["state"]}, sock_path).get("print_stats", {}).get("state")
    return state in ACTIVE_STATES, state


def wait_ready(sock_path, timeout):
    """Klipper refuses socket connections while it reloads, so poll until ready."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        time.sleep(1)
        try:
            status = query({"webhooks": ["state"]}, sock_path)
        except (KlipperError, OSError, ValueError):
            continue
        if status.get("webhooks", {}).get("state") == "ready":
            return True
    return False


def cmd_state(args):
    status = query({"print_stats": None, "virtual_sdcard": ["progress"]}, args.socket)
    stats = status.get("print_stats", {})
    progress = status.get("virtual_sdcard", {}).get("progress") or 0.0
    state = stats.get("state")
    print(json.dumps({
        "state": state,
        "active": state in ACTIVE_STATES,
        "filename": stats.get("filename") or None,
        "progress_pct": round(progress * 100, 1),
    }, indent=2))
    return 0


def cmd_limits(args):
    head = query({"toolhead": ["axis_minimum", "axis_maximum", "homed_axes"]}, args.socket).get("toolhead", {})
    low, high = head.get("axis_minimum") or [], head.get("axis_maximum") or []
    for i, axis in enumerate("xyz"):
        if i < len(low) and i < len(high):
            print("%s: %s .. %s" % (axis, low[i], high[i]))
    print("homed: %s" % (head.get("homed_axes") or "(none)"))
    return 0


def cmd_query(args):
    print(json.dumps(query(parse_objects(args.objects), args.socket), indent=2, sort_keys=True))
    return 0


def cmd_cfg(args):
    settings = query({"configfile": ["settings"]}, args.socket).get("configfile", {}).get("settings", {})
    if not args.sections:
        for name in sorted(settings):
            print(name)
        return 0
    missing = 0
    for section in args.sections:
        if section in settings:
            print("[%s]" % section)
            print(json.dumps(settings[section], indent=2, sort_keys=True))
        else:
            print("[%s] not found" % section, file=sys.stderr)
            missing = 1
    return missing


def cmd_gcode(args):
    call("gcode/script", {"script": args.script}, args.socket)
    print("ok")
    return 0


def cmd_restart(args):
    if not args.force:
        active, state = print_is_active(args.socket)
        if active:
            raise KlipperError("refusing FIRMWARE_RESTART while print state is '%s' (use --force)" % state)
    call("gcode/script", {"script": "FIRMWARE_RESTART"}, args.socket)
    print("FIRMWARE_RESTART sent, waiting for Klipper to come back...")
    if not wait_ready(args.socket, args.timeout):
        print("timed out waiting for Klipper to become ready", file=sys.stderr)
        return 1
    print("Klipper ready")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Query and control Klipper over its unix API socket.")
    parser.add_argument("--socket", default=DEFAULT_SOCKET, help="Klipper API socket (default %s)" % DEFAULT_SOCKET)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("state", help="print state; check before any change").set_defaults(func=cmd_state)
    sub.add_parser("limits", help="live axis limits and homed axes").set_defaults(func=cmd_limits)

    p_query = sub.add_parser("query", help="query objects, e.g. toolhead:position extruder")
    p_query.add_argument("objects", nargs="+")
    p_query.set_defaults(func=cmd_query)

    p_cfg = sub.add_parser("cfg", help="list config sections, or dump the named ones")
    p_cfg.add_argument("sections", nargs="*")
    p_cfg.set_defaults(func=cmd_cfg)

    p_gcode = sub.add_parser("gcode", help="run a gcode command")
    p_gcode.add_argument("script")
    p_gcode.set_defaults(func=cmd_gcode)

    p_restart = sub.add_parser("restart", help="FIRMWARE_RESTART, refused while printing")
    p_restart.add_argument("--force", action="store_true", help="restart even during a print")
    p_restart.add_argument("--timeout", type=int, default=30, help="seconds to wait for ready")
    p_restart.set_defaults(func=cmd_restart)
    return parser


def main():
    args = build_parser().parse_args()
    try:
        return args.func(args)
    except KlipperError as exc:
        print("Error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
