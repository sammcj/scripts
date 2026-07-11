# kq.py

Query and control Klipper over its unix API socket (`/tmp/klippy_uds`).

Runs on the printer, where the socket lives. Written against Python 3.9 with no
dependencies, so it works on stock Creality/OpenWrt firmware where there is no
`curl` and Moonraker may be busy.

## Usage

```sh
python3 kq.py state          # print state - check this before changing anything
python3 kq.py limits         # live axis min/max and homed axes
python3 kq.py query toolhead:position,homed_axes extruder:temperature
python3 kq.py cfg            # list config section names
python3 kq.py cfg stepper_y  # dump a section as JSON
python3 kq.py gcode "M115"
python3 kq.py restart        # FIRMWARE_RESTART
```

`--socket PATH` points at a different socket. Every subcommand exits non-zero on
error, so it composes in scripts.

`restart` refuses to run while `print_stats.state` is `printing` or `paused`.
Pass `--force` to override, which will abort the print.

Copy it over and run it there:

```sh
scp kq.py root@PRINTER:/tmp/
ssh root@PRINTER 'python3 /tmp/kq.py state'
```

`/tmp` is a tmpfs on these printers, so it is cleared on reboot. That is usually
what you want for a throwaway tool.

## Why the socket and not Moonraker

`objects/query` reads Klipper's live state directly, which is the only place some
values exist. A Creality K2 Pro overrides `stepper_y.position_max` at runtime
from a `[gcode_macro PRINTER_PARAM]` variable, so the config file lies and
`toolhead.axis_maximum` tells the truth:

```sh
python3 kq.py cfg stepper_y   # position_max: 332.0   (ignored)
python3 kq.py limits          # y: -6.5 .. 306.0      (actual)
```
