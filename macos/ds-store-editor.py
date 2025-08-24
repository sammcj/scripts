#!/usr/bin/env python3
"""
DS_Store Window Dimension Editor
Sets consistent window dimensions across all .DS_Store files
"""

import os
import sys
import argparse
from pathlib import Path

try:
    from ds_store import DSStore
except ImportError:
    print("Error: ds_store module not found. Install it with: pip install ds-store")
    sys.exit(1)

def set_window_bounds(ds_store_path, x, y, width, height):
    """
    Set window bounds in a .DS_Store file
    
    The fwi0 record contains window information in this format:
    - 16 bytes: window bounds (top, left, bottom, right as 4-byte integers)
    - Additional data for other window properties
    """
    try:
        with DSStore.open(ds_store_path, 'r+') as ds:
            # Calculate bounds (macOS uses top-left and bottom-right corners)
            top = y
            left = x
            bottom = y + height
            right = x + width
            
            # Create the fwi0 data structure
            # This is a 16-byte blob containing the window bounds
            import struct
            # Pack as 4 signed shorts (16-bit integers)
            fwi0_data = struct.pack('>4h', top, left, bottom, right)
            # Add padding to make it at least 16 bytes (some versions need more)
            if len(fwi0_data) < 16:
                fwi0_data += b'\x00' * (16 - len(fwi0_data))
            
            # Remove existing fwi0 entry if it exists
            entries_to_remove = []
            for entry in ds:
                if entry.filename == '.' and entry.code == b'fwi0':
                    entries_to_remove.append(entry)
            
            for entry in entries_to_remove:
                ds.remove(entry)
            
            # Add the new entry
            ds.insert(DSStore.DSStoreEntry('.', b'fwi0', fwi0_data))
            
            # Also set icon view on if not already set
            has_icvo = False
            for entry in ds:
                if entry.filename == '.' and entry.code == b'ICVO':
                    has_icvo = True
                    break
            
            if not has_icvo:
                ds.insert(DSStore.DSStoreEntry('.', b'ICVO', True))
            
            ds.flush()
            print(f"✓ Updated {ds_store_path}")
            return True
            
    except Exception as e:
        print(f"✗ Error updating {ds_store_path}: {e}")
        return False

def find_ds_store_files(root_path, recursive=True):
    """Find all .DS_Store files in the given path"""
    ds_store_files = []
    
    if recursive:
        for root, dirs, files in os.walk(root_path):
            if '.DS_Store' in files:
                ds_store_files.append(os.path.join(root, '.DS_Store'))
    else:
        ds_store_path = os.path.join(root_path, '.DS_Store')
        if os.path.exists(ds_store_path):
            ds_store_files.append(ds_store_path)
    
    return ds_store_files

def read_window_bounds(ds_store_path):
    """Read and display current window bounds from a .DS_Store file"""
    try:
        with DSStore.open(ds_store_path, 'r') as ds:
            found_window_info = False
            
            # Iterate through all entries in the DS_Store file
            for entry in ds:
                filename = entry.filename
                code = entry.code
                
                # Look for window-related entries for the current directory ('.')
                if filename == '.':
                    if code == b'fwi0':
                        # Window information found
                        import struct
                        fwi0_data = entry.value
                        if isinstance(fwi0_data, bytes) and len(fwi0_data) >= 16:
                            # Unpack as 4 signed shorts (16-bit integers)
                            bounds = struct.unpack('>4h', fwi0_data[:16])
                            top, left, bottom, right = bounds
                            width = right - left
                            height = bottom - top
                            print(f"  Window bounds: position=({left},{top}), size={width}x{height}")
                            found_window_info = True
                        else:
                            print("  ⚠️  Window data exists but is incomplete")
                    
                    elif code == b'fwsw':
                        # Sidebar width
                        if isinstance(entry.value, int):
                            print(f"  Sidebar width: {entry.value} pixels")
                        found_window_info = True
                    
                    elif code == b'fwvh':
                        # Window height override
                        if isinstance(entry.value, int):
                            print(f"  Window height: {entry.value} pixels")
                        found_window_info = True
            
            if not found_window_info:
                print("  ℹ️  No window bounds stored")
                    
    except FileNotFoundError:
        print(f"  ❌ File not found: {ds_store_path}")
    except Exception as e:
        print(f"  ❌ Error reading: {e}")
        # Try alternative method using raw iteration
        try:
            print("  Attempting alternative read method...")
            with DSStore.open(ds_store_path, 'r') as ds:
                # List all entries for debugging
                for entry in ds:
                    if hasattr(entry, 'filename') and entry.filename == '.':
                        print(f"    Found entry: {entry.code} = {type(entry.value)}")
        except:
            pass

def main():
    parser = argparse.ArgumentParser(
        description='Edit window dimensions in .DS_Store files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Show current window dimensions (default)
  %(prog)s
  
  # Set window dimensions for current directory
  %(prog)s --set 100 100 1200 800
  
  # Set dimensions for a specific directory
  %(prog)s --path /path/to/folder --set 100 100 1200 800
  
  # Apply to all subdirectories recursively
  %(prog)s --recursive --set 100 100 1200 800
  
  # Show dimensions for a specific directory
  %(prog)s --path /path/to/folder
        """
    )
    
    parser.add_argument('--path', type=str, default='.',
                        help='Path to directory (default: current directory)')
    parser.add_argument('--recursive', '-r', action='store_true',
                        help='Apply to all subdirectories recursively')
    parser.add_argument('--set', nargs=4, type=int, metavar=('X', 'Y', 'WIDTH', 'HEIGHT'),
                        help='Set window position and size')
    parser.add_argument('--create', action='store_true',
                        help='Create .DS_Store files if they don\'t exist')
    
    args = parser.parse_args()
    
    # Default to read mode if no action specified
    read_mode = not args.set
    
    # Expand path
    root_path = os.path.expanduser(args.path)
    
    if read_mode:
        # Read mode (default when no arguments provided)
        if args.recursive:
            # Show all .DS_Store files recursively
            ds_store_files = find_ds_store_files(root_path, True)
            if ds_store_files:
                print(f"Found {len(ds_store_files)} .DS_Store file(s):\n")
                for ds_file in sorted(ds_store_files):
                    rel_path = os.path.relpath(ds_file, root_path)
                    print(f"📁 {os.path.dirname(rel_path) or '.'}")
                    read_window_bounds(ds_file)
                    print()
            else:
                print(f"No .DS_Store files found in {root_path}")
        else:
            # Single directory mode
            ds_store_path = os.path.join(root_path, '.DS_Store')
            if os.path.exists(ds_store_path):
                print(f"📁 {root_path}")
                read_window_bounds(ds_store_path)
            else:
                print(f"No .DS_Store file found at {root_path}")
                print("Finder may not have saved window preferences for this folder yet.")
                print("Try opening the folder in Finder and adjusting the window.")
    
    else:
        # Set mode
        x, y, width, height = args.set
        print(f"Setting window bounds: position=({x},{y}), size=({width}x{height})")
        
        if args.create and not os.path.exists(os.path.join(root_path, '.DS_Store')):
            # Create an empty .DS_Store file if it doesn't exist
            try:
                with DSStore.open(os.path.join(root_path, '.DS_Store'), 'w') as ds:
                    pass
            except Exception as e:
                print(f"Error creating .DS_Store: {e}")
        
        # Find all .DS_Store files
        ds_store_files = find_ds_store_files(root_path, args.recursive)
        
        if not ds_store_files:
            print("No .DS_Store files found")
            if not args.create:
                print("Use --create to create .DS_Store files")
            return
        
        # Update each file
        success_count = 0
        for ds_file in ds_store_files:
            if set_window_bounds(ds_file, x, y, width, height):
                success_count += 1
        
        print(f"\nUpdated {success_count}/{len(ds_store_files)} files")

if __name__ == '__main__':
    main()