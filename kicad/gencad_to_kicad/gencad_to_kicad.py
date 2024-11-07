#!/usr/bin/env python

# Usage:
# python gencad2kicad.py input.cad output.kicad_pcb

import sys
import re
import os
import argparse
from pathlib import Path
from typing import Dict, List, Tuple
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# Find and add KiCad's Python modules to path on macOS
def setup_kicad_path():
    possible_paths = [
        "/Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/lib/python3.*/site-packages",
        "/Applications/KiCad/KiCad.app/Contents/Frameworks/python/site-packages",
        "/Library/Application Support/kicad/scripting/plugins",
    ]

    for path_pattern in possible_paths:
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


if not setup_kicad_path():
    logger.error("Could not find KiCad Python modules.")
    sys.exit(1)

try:
    import pcbnew
except ImportError as e:
    logger.error(f"Error importing pcbnew: {e}")
    sys.exit(1)


class GenCADParser:
    def __init__(self):
        self.units = "MM"  # Default to millimeters
        self.components = []
        self.padstacks = {}
        self.signals = {}
        self.board_outline = []
        self.tracks = []
        self.vias = []
        self.current_section = None
        self.component_shapes = {}

    def parse_file(self, filename: str):
        """Parse GenCAD file"""
        with open(filename, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("$"):
                    continue

                parts = line.split()
                command = parts[0].upper()

                if command == "HEADER":
                    self.current_section = "HEADER"
                elif command == "UNITS":
                    self.parse_units(parts)
                elif command == "SHAPE":
                    self.parse_shape(parts)
                elif command == "PADSTACK":
                    self.parse_padstack(parts)
                elif command == "SIGNAL":
                    self.parse_signal(parts)
                elif command == "COMPONENT":
                    self.parse_component(parts)
                elif command == "BOARD":
                    self.parse_board(parts)
                elif command == "TRACK":
                    self.parse_track(parts)
                elif command == "VIA":
                    self.parse_via(parts)

    def parse_units(self, parts):
        """Parse UNITS section"""
        if len(parts) > 1:
            self.units = parts[1].upper()

    def parse_shape(self, parts):
        """Parse SHAPE section"""
        if len(parts) > 1:
            shape_name = parts[1]
            self.component_shapes[shape_name] = {
                "name": shape_name,
                "pads": [],
                "outline": [],
            }
            self.current_section = f"SHAPE_{shape_name}"

    def parse_padstack(self, parts):
        """Parse PADSTACK section"""
        if len(parts) > 1:
            pad_name = parts[1]
            self.padstacks[pad_name] = {
                "name": pad_name,
                "shape": parts[2] if len(parts) > 2 else "ROUND",
                "dimensions": [],
            }

    def parse_signal(self, parts):
        """Parse SIGNAL section"""
        if len(parts) > 1:
            signal_name = parts[1]
            self.signals[signal_name] = {"name": signal_name, "nodes": []}

    def parse_component(self, parts):
        """Parse COMPONENT section"""
        if len(parts) > 3:
            component = {
                "reference": parts[1],
                "shape": parts[2],
                "x": float(parts[3]),
                "y": float(parts[4]) if len(parts) > 4 else 0,
                "rotation": float(parts[5]) if len(parts) > 5 else 0,
                "side": parts[6] if len(parts) > 6 else "TOP",
            }
            self.components.append(component)

    def parse_board(self, parts):
        """Parse BOARD outline"""
        if len(parts) > 2:
            try:
                x = float(parts[1])
                y = float(parts[2])
                self.board_outline.append((x, y))
            except ValueError:
                logger.warning(f"Invalid board coordinates: {parts}")

    def convert_to_kicad_pcb(self, output_file: str):
        """Convert parsed GenCAD data to KiCad PCB format"""
        board = pcbnew.BOARD()

        # Set up board characteristics
        board_settings = board.GetDesignSettings()

        # Convert board outline
        if self.board_outline:
            outline = pcbnew.PCB_SHAPE(board)
            outline.SetShape(pcbnew.SHAPE_T_POLY)
            points = []
            for x, y in self.board_outline:
                points.append(
                    pcbnew.VECTOR2I(self.convert_to_nm(x), self.convert_to_nm(y))
                )
            outline.SetPolyPoints(points)
            board.Add(outline)

        # Create nets
        netinfo = board.GetNetInfo()
        for signal_name, signal_data in self.signals.items():
            netinfo.AddNet(signal_name)

        # Place components
        for comp in self.components:
            module = pcbnew.PCB_FOOTPRINT(board)
            module.SetReference(comp["reference"])

            # Set position
            pos = pcbnew.VECTOR2I(
                self.convert_to_nm(comp["x"]), self.convert_to_nm(comp["y"])
            )
            module.SetPosition(pos)

            # Set rotation
            if comp["rotation"]:
                module.SetOrientation(
                    comp["rotation"] * 10
                )  # KiCad uses tenths of degrees

            # Set layer (TOP/BOTTOM)
            if comp["side"].upper() == "BOTTOM":
                module.Flip(module.GetPosition(), False)

            board.Add(module)

        # Add tracks
        for track in self.tracks:
            pcb_track = pcbnew.PCB_TRACK(board)
            pcb_track.SetStart(
                pcbnew.VECTOR2I(
                    self.convert_to_nm(track["start_x"]),
                    self.convert_to_nm(track["start_y"]),
                )
            )
            pcb_track.SetEnd(
                pcbnew.VECTOR2I(
                    self.convert_to_nm(track["end_x"]),
                    self.convert_to_nm(track["end_y"]),
                )
            )
            pcb_track.SetWidth(self.convert_to_nm(track["width"]))
            board.Add(pcb_track)

        # Save the board
        pcbnew.SaveBoard(output_file, board)

    def convert_to_nm(self, value: float) -> int:
        """Convert units to nanometers"""
        if self.units == "MM":
            return int(value * 1000000)  # mm to nm
        elif self.units == "INCH":
            return int(value * 25400000)  # inch to nm
        else:
            logger.warning(f"Unknown unit: {self.units}, assuming MM")
            return int(value * 1000000)


def main():
    parser = argparse.ArgumentParser(
        description="Convert GenCAD files to KiCad PCB format"
    )
    parser.add_argument("input_file", help="Input .cad file")
    parser.add_argument("output_file", help="Output .kicad_pcb file")
    parser.add_argument(
        "--kicad-path", help="Custom KiCad installation path", default=None
    )
    args = parser.parse_args()

    # Add custom KiCad path if provided
    if args.kicad_path:
        python_path = os.path.join(
            args.kicad_path, "Contents/Frameworks/python/site-packages"
        )
        if os.path.exists(python_path):
            sys.path.append(python_path)
        else:
            logger.warning(f"Custom KiCad path {python_path} not found")

    try:
        gencad_parser = GenCADParser()
        logger.info(f"Parsing GenCAD file: {args.input_file}")
        gencad_parser.parse_file(args.input_file)

        logger.info(f"Converting to KiCad PCB format: {args.output_file}")
        gencad_parser.convert_to_kicad_pcb(args.output_file)

        logger.info("Conversion complete!")

    except Exception as e:
        logger.error(f"Error during conversion: {e}")
        raise


if __name__ == "__main__":
    main()
