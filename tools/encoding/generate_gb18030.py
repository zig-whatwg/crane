#!/usr/bin/env python3
"""Generate gb18030 index file from WHATWG encoding index."""

import urllib.request

GB18030_INDEX_URL = "https://encoding.spec.whatwg.org/index-gb18030.txt"
GB18030_RANGES_URL = "https://encoding.spec.whatwg.org/index-gb18030-ranges.txt"

def download_index(url):
    """Download index file from WHATWG."""
    with urllib.request.urlopen(url) as response:
        return response.read().decode('utf-8')

def parse_gb18030_index(content):
    """Parse gb18030 index file."""
    entries = []
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) >= 2:
            pointer = int(parts[0])
            code_point = int(parts[1], 16)
            entries.append((pointer, code_point))
    return entries

def parse_gb18030_ranges(content):
    """Parse gb18030-ranges index file."""
    entries = []
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) >= 2:
            pointer = int(parts[0])
            code_point = int(parts[1], 16)
            entries.append((pointer, code_point))
    return entries

def generate_gb18030_index_zig(entries):
    """Generate Zig source for gb18030 index."""
    lines = [
        "//! gb18030 Index",
        "//!",
        "//! WHATWG Encoding Standard",
        "//! https://encoding.spec.whatwg.org/#gb18030",
        "//!",
        "//! This index maps pointer values (0-23939) to Unicode code points.",
        "//! Used by the gb18030 decoder for 2-byte sequences.",
        "",
        "/// gb18030 index: pointer -> code point mapping",
        f"pub const INDEX: [23940]u21 = .{{",
    ]
    
    # Generate array with 8 entries per line
    for i in range(0, len(entries), 8):
        chunk = entries[i:i+8]
        hex_values = [f"0x{cp:04X}" for _, cp in chunk]
        comment = f"// {i:5d}-{min(i+7, len(entries)-1):5d}"
        comma = "," if i + 8 < len(entries) else ""
        lines.append(f"    {', '.join(hex_values)}{comma:57s} {comment}")
    
    lines.append("};")
    lines.append("")
    
    return '\n'.join(lines)

def generate_gb18030_ranges_zig(entries):
    """Generate Zig source for gb18030-ranges index."""
    lines = [
        "//! gb18030 Ranges Index",
        "//!",
        "//! WHATWG Encoding Standard",
        "//! https://encoding.spec.whatwg.org/#index-gb18030-ranges",
        "//!",
        "//! This index defines ranges for 4-byte sequence decoding.",
        "//! Each entry maps a pointer to the start of a Unicode code point range.",
        "",
        "/// Range entry: (pointer, code_point)",
        "pub const Range = struct {",
        "    pointer: u32,",
        "    code_point: u21,",
        "};",
        "",
        "/// gb18030 ranges: used for 4-byte sequence decoding",
        f"pub const RANGES: [{len(entries)}]Range = .{{",
    ]
    
    for pointer, code_point in entries:
        lines.append(f"    .{{ .pointer = {pointer:6d}, .code_point = 0x{code_point:04X} }},")
    
    lines.append("};")
    lines.append("")
    
    return '\n'.join(lines)

def main():
    print("Downloading gb18030 index...")
    gb18030_content = download_index(GB18030_INDEX_URL)
    entries = parse_gb18030_index(gb18030_content)
    print(f"Parsed {len(entries)} gb18030 entries")
    
    print("Generating src/chinese/gb18030_index.zig...")
    zig_code = generate_gb18030_index_zig(entries)
    with open('src/chinese/gb18030_index.zig', 'w') as f:
        f.write(zig_code)
    print(f"Generated gb18030_index.zig ({len(zig_code)} bytes)")
    
    print("\nDownloading gb18030-ranges index...")
    ranges_content = download_index(GB18030_RANGES_URL)
    range_entries = parse_gb18030_ranges(ranges_content)
    print(f"Parsed {len(range_entries)} gb18030-ranges entries")
    
    print("Generating src/chinese/gb18030_ranges.zig...")
    ranges_code = generate_gb18030_ranges_zig(range_entries)
    with open('src/chinese/gb18030_ranges.zig', 'w') as f:
        f.write(ranges_code)
    print(f"Generated gb18030_ranges.zig ({len(ranges_code)} bytes)")
    
    print("\n✅ Generation complete!")

if __name__ == '__main__':
    main()
