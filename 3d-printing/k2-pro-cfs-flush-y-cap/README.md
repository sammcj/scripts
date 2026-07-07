# K2 Pro CFS-flush Y-cap fix

Fixes a Creality K2 Pro crash at print start where the CFS (multi-material) filament flush is rejected as out of range:

```
{"code":"key586","msg":"Move out of range: 205.654 303.056 3.393 [161.040]"}
```

## Cause

A firmware update reverts `printer_data/config` and resets `variable_max_y_position` (in `[gcode_macro PRINTER_PARAM]`) to `302.0`. On the K2 Pro that value lands right at the rear edge of the region where master-server composes the CFS filament flush, so the flush move (observed around Y302.2-303.1) overshoots the Klipper Y limit by a fraction and the print aborts.

The value that actually caps Y is this macro variable, not the `position_max` in `[stepper_y]` (which is 332) - Creality's `klippy/stepper.py` overrides `stepper_y.position_max` with `variable_max_y_position`. So raising the macro variable is what moves the limit.

Not a slicer, mesh or KAMP issue - the flush is composed by the closed-source master-server daemon. It is a regression in the stock 302.0 value being too tight for Creality's own flush move.

## Fix

Raise the cap to 306 (about 3mm of clearance over the observed flush ceiling; the box arm physically reaches Y=329 in normal CFS ops, so 306 is well inside the mechanical envelope).

Run on the printer after each firmware update:

```sh
python3 fix_k2pro_y_cap.py
```

Idempotent - a no-op if the cap is already at or above the target. It backs up `gcode_macro.cfg` (timestamped `.ycap.bak-*`), edits the value, `FIRMWARE_RESTART`s, and verifies the live `axis_maximum.y` over the Klipper unix socket (`/tmp/klippy_uds`).

```sh
python3 fix_k2pro_y_cap.py --dry-run       # show the change, write nothing
python3 fix_k2pro_y_cap.py --target 308    # different cap (must be 303 < t < 329)
python3 fix_k2pro_y_cap.py --no-restart    # edit only, restart later
```

## Evidence

Deterministic. The failing flush overshoots whatever cap sits at the region edge:

- cap 302.0 -> flush rejected at Y302.228
- cap 303.0 -> flush rejected at Y303.056
- cap 306.0 -> flush clears, print runs

## Notes

- Firmware updates wipe this - re-run after every update.
- Requires Python 3 (present on the printer) and a running Klipper. No extra packages.
- Confirmed on a K2 Pro (board CR0CN200400C10, F021). Logic is model-agnostic but untested on other K2 variants.
