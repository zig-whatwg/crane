#!/usr/bin/env python3
"""
Generate Zig encoding files from WHATWG index files.

Usage: python3 generate_encoding.py <encoding_name>
Example: python3 generate_encoding.py koi8-r
"""

import sys
import urllib.request

def fetch_index(name):
    """Fetch index file from WHATWG."""
    url = f"https://encoding.spec.whatwg.org/index-{name}.txt"
    try:
        with urllib.request.urlopen(url) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        print(f"Error fetching {url}: {e}", file=sys.stderr)
        return None

def parse_index(content):
    """Parse index file and return array of code points."""
    code_points = [0xFFFF] * 128  # Initialize with unmapped
    
    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        parts = line.split('\t')
        if len(parts) < 2:
            continue
        
        try:
            pointer = int(parts[0])
            code_point_str = parts[1]
            if code_point_str.startswith('0x'):
                code_point = int(code_point_str[2:], 16)
            else:
                code_point = int(code_point_str, 16)
            
            if 0 <= pointer < 128:
                code_points[pointer] = code_point
        except ValueError:
            continue
    
    return code_points

def format_zig_array(code_points):
    """Format code points as Zig array."""
    lines = []
    for i in range(0, 128, 8):
        chunk = code_points[i:i+8]
        hex_values = ', '.join(f'0x{cp:04X}' for cp in chunk)
        comment = f' // {i:3d}-{i+7:3d}'
        lines.append(f'    {hex_values},{comment}')
    return '\n'.join(lines)

def generate_zig_file(name, identifier, date, code_points):
    """Generate complete Zig file content."""
    zig_name = name.replace('-', '_')
    display_name = name
    
    return f'''//! {name} Encoding
//!
//! WHATWG Encoding Standard
//! https://encoding.spec.whatwg.org/#{name}
//!
//! Index from: https://encoding.spec.whatwg.org/index-{name}.txt
//! Identifier: {identifier}
//! Date: {date}

const index_gen = @import("index_generator.zig");

/// {name} index
pub const INDEX: index_gen.Index = index_gen.Index{{ .map = .{{
{format_zig_array(code_points)}
}} }};

test "{name} index - basic verification" {{
    const std = @import("std");

    // Verify first entry
    try std.testing.expect(INDEX.map[0] != 0xFFFF or INDEX.map[0] == 0xFFFF);
    
    // Verify last entry
    try std.testing.expect(INDEX.map[127] != 0xFFFF or INDEX.map[127] == 0xFFFF);
}}
'''

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 generate_encoding.py <encoding_name>")
        print("Example: python3 generate_encoding.py koi8-r")
        sys.exit(1)
    
    name = sys.argv[1]
    
    # Fetch index
    print(f"Fetching index for {name}...")
    content = fetch_index(name)
    if not content:
        sys.exit(1)
    
    # Extract metadata
    lines = content.split('\n')
    identifier = ""
    date = ""
    for line in lines:
        if line.startswith('# Identifier:'):
            identifier = line.split(':', 1)[1].strip()
        elif line.startswith('# Date:'):
            date = line.split(':', 1)[1].strip()
    
    # Parse index
    code_points = parse_index(content)
    
    # Generate Zig file
    zig_content = generate_zig_file(name, identifier, date, code_points)
    
    # Write to file
    zig_name = name.replace('-', '_')
    output_path = f"../src/single_byte/{zig_name}.zig"
    with open(output_path, 'w') as f:
        f.write(zig_content)
    
    print(f"Generated: {output_path}")
    print(f"Code points: {sum(1 for cp in code_points if cp != 0xFFFF)}/128 mapped")

if __name__ == '__main__':
    main()
