#!/usr/bin/env python

# Basic usage
# python boardview2kicad.py input.brd output.kicad_pcb
# With custom KiCad path
# python boardview2kicad.py input.brd output.kicad_pcb --kicad-path "/Applications/Custom/KiCad.app"

import sys
import os
import re
import argparse
from pathlib import Path


# Find and add KiCad's Python modules to path on macOS
def setup_kicad_path():
    # Common KiCad installation locations on macOS
    possible_paths = [
        "/Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/lib/python3.*/site-packages",
        "/Applications/KiCad/KiCad.app/Contents/Frameworks/python/site-packages",
        "/Library/Application Support/kicad/scripting/plugins",
    ]

    for path_pattern in possible_paths:
        # Handle wildcard paths
        if "*" in path_pattern:
            from glob import glob

            matching_paths = glob(path_pattern)
            for path in matching_paths:
                if os.path.exists(path):
                    sys.path.append(path)
                    return True
        else:
            if os.path.exists(path_pattern):
                sys.path.append(path_pattern)
                return True

    return False


# Try to set up KiCad path and import pcbnew
if not setup_kicad_path():
    print("Error: Could not find KiCad Python modules.")
    print("Please ensure KiCad is installed in /Applications/KiCad/")
    print("Current Python path:", sys.path)
    sys.exit(1)

try:
    import pcbnew # type: ignore
except ImportError as e:
    print(f"Error importing pcbnew: {e}")
    print("Please ensure KiCad is properly installed.")
    print("Current Python path:", sys.path)
    sys.exit(1)

class BoardviewReader:
    def __init__(self):
        self.nets = {}  # net_code -> net_name
        self.parts = []  # list of component data
        self.pins = []  # list of pin data
        self.nails = []  # list of test points
        self.outline = []  # board outline points
        self.board_width = 0
        self.board_height = 0

    def parse_brd(self, brd_file):
        """Parse .brd format file"""
        current_section = None
        for line in brd_file:
            line = line.strip()
            if not line:
                current_section = None
                continue

            if line.startswith("BRDOUT:"):
                current_section = "outline"
                _, count, width, height = line.split()
                self.board_width = float(width)
                self.board_height = float(height)
                continue

            if line.startswith("NETS:"):
                current_section = "nets"
                continue

            if line.startswith("PARTS:"):
                current_section = "parts"
                continue

            if line.startswith("PINS:"):
                current_section = "pins"
                continue

            if line.startswith("NAILS:"):
                current_section = "nails"
                continue

            if current_section == "outline":
                try:
                    x, y = map(float, line.split())
                    self.outline.append((x, y))
                except ValueError:
                    continue

            elif current_section == "nets":
                try:
                    code, name = line.split(maxsplit=1)
                    self.nets[int(code)] = name
                except ValueError:
                    continue

            elif current_section == "parts":
                try:
                    ref, x1, y1, x2, y2, pin, side = line.split()
                    self.parts.append(
                        {
                            "reference": ref,
                            "x1": float(x1),
                            "y1": float(y1),
                            "x2": float(x2),
                            "y2": float(y2),
                            "pin_start": int(pin),
                            "side": int(side),
                        }
                    )
                except ValueError:
                    continue

            elif current_section == "pins":
                try:
                    x, y, net, side = line.split()
                    self.pins.append(
                        {
                            "x": float(x),
                            "y": float(y),
                            "net": int(net),
                            "side": int(side),
                        }
                    )
                except ValueError:
                    continue

            elif current_section == "nails":
                try:
                    probe, x, y, net, side = line.split()
                    self.nails.append(
                        {
                            "probe": probe,
                            "x": float(x),
                            "y": float(y),
                            "net": int(net),
                            "side": int(side),
                        }
                    )
                except ValueError:
                    continue

    def convert_to_nm(self, mils):
        """Convert mils to nanometers (KiCad internal units)"""
        return int(mils * 25400)  # 1 mil = 25400 nm

    def create_kicad_pcb(self, output_file):
        """Create a new KiCad PCB file"""
        board = pcbnew.BOARD()

        # Create board outline
        outline_shape = pcbnew.PCB_SHAPE(board)
        outline_shape.SetShape(pcbnew.SHAPE_T_POLY)
        outline_points = []

        for x, y in self.outline:
            point = pcbnew.VECTOR2I(self.convert_to_nm(x), self.convert_to_nm(y))
            outline_points.append(point)

        outline_shape.SetPolyPoints(outline_points)
        board.Add(outline_shape)

        # Create nets
        netinfo = board.GetNetInfo()
        for net_code, net_name in self.nets.items():
            netinfo.AddNet(net_name)

        # Create test points
        for nail in self.nails:
            module = pcbnew.PCB_FOOTPRINT(board)
            module.SetReference(f"TP{nail['probe']}")
            module.SetValue("TestPoint")

            # Create a pad for the test point
            pad = pcbnew.PCB_PAD(module)
            pad.SetShape(pcbnew.PAD_SHAPE_CIRCLE)
            pad.SetSize(
                pcbnew.VECTOR2I(self.convert_to_nm(10), self.convert_to_nm(10))
            )  # 10 mil diameter
            pad.SetPosition(
                pcbnew.VECTOR2I(
                    self.convert_to_nm(nail["x"]), self.convert_to_nm(nail["y"])
                )
            )

            net = netinfo.GetNet(self.nets[nail["net"]])
            pad.SetNet(net)
            module.Add(pad)
            board.Add(module)

        # Save the board
        pcbnew.SaveBoard(output_file, board)


def main():
    parser = argparse.ArgumentParser(
        description="Convert Boardview files to KiCad PCB format"
    )
    parser.add_argument("input_file", help="Input .brd or .bvr file")
    parser.add_argument("output_file", help="Output .kicad_pcb file")
    parser.add_argument(
        "--kicad-path", help="Custom KiCad installation path", default=None
    )
    args = parser.parse_args()

    # If custom KiCad path provided, add it to Python path
    if args.kicad_path:
        python_path = os.path.join(
            args.kicad_path, "Contents/Frameworks/python/site-packages"
        )
        if os.path.exists(python_path):
            sys.path.append(python_path)
        else:
            print(f"Warning: Custom KiCad path {python_path} not found")

    reader = BoardviewReader()

    with open(args.input_file, "r") as f:
        if args.input_file.lower().endswith(".brd"):
            reader.parse_brd(f)
        else:
            print("Currently only .brd format is supported")
            sys.exit(1)

    try:
        reader.create_kicad_pcb(args.output_file)
        print(f"Conversion complete. Output saved to {args.output_file}")
    except Exception as e:
        print(f"Error during conversion: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
