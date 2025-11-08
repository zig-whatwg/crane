#!/usr/bin/env python3
"""Generate Japanese and Korean encoding index files from WHATWG encoding indexes."""

import urllib.request

# Index URLs from WHATWG Encoding Standard
JIS0208_INDEX_URL = "https://encoding.spec.whatwg.org/index-jis0208.txt"
JIS0212_INDEX_URL = "https://encoding.spec.whatwg.org/index-jis0212.txt"
ISO2022JP_KATAKANA_INDEX_URL = "https://encoding.spec.whatwg.org/index-iso-2022-jp-katakana.txt"
EUC_KR_INDEX_URL = "https://encoding.spec.whatwg.org/index-euc-kr.txt"

def download_index(url):
    """Download index file from WHATWG."""
    with urllib.request.urlopen(url) as response:
        return response.read().decode('utf-8')

def parse_index(content):
    """Parse index file (format: pointer\tcode_point)."""
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

def generate_index_zig(entries, index_name, description, max_pointer):
    """Generate Zig source for an index."""
    # Create full array with zeros, then fill in entries
    full_array = [0] * (max_pointer + 1)
    for pointer, code_point in entries:
        if pointer <= max_pointer:
            full_array[pointer] = code_point
    
    lines = [
        f"//! {index_name} Index",
        "//!",
        "//! WHATWG Encoding Standard",
        f"//! {description}",
        "//!",
        f"//! This index maps pointer values (0-{max_pointer}) to Unicode code points.",
        f"//! Entries with value 0 indicate unmapped pointers.",
        "",
        f"/// {index_name} index: pointer -> code point mapping",
        f"pub const INDEX: [{max_pointer + 1}]u21 = .{{",
    ]
    
    # Generate array with 8 entries per line
    for i in range(0, len(full_array), 8):
        chunk = full_array[i:i+8]
        hex_values = [f"0x{cp:04X}" for cp in chunk]
        comment = f"// {i:5d}-{min(i+7, len(full_array)-1):5d}"
        comma = "," if i + 8 < len(full_array) else ""
        lines.append(f"    {', '.join(hex_values)}{comma:57s} {comment}")
    
    lines.append("};")
    lines.append("")
    
    return '\n'.join(lines)

def generate_small_index_zig(entries, index_name, description):
    """Generate Zig source for a small index (one entry per line)."""
    lines = [
        f"//! {index_name} Index",
        "//!",
        "//! WHATWG Encoding Standard",
        f"//! {description}",
        "//!",
        "//! This index is used by the ISO-2022-JP encoder to convert",
        "//! halfwidth katakana to fullwidth katakana.",
        "",
        f"/// {index_name} index entry",
        "pub const Entry = struct {",
        "    pointer: u8,",
        "    code_point: u21,",
        "};",
        "",
        f"/// {index_name} index: pointer -> code point mapping",
        f"pub const INDEX: [{len(entries)}]Entry = .{{",
    ]
    
    for pointer, code_point in entries:
        lines.append(f"    .{{ .pointer = 0x{pointer:02X}, .code_point = 0x{code_point:04X} }},")
    
    lines.append("};")
    lines.append("")
    
    return '\n'.join(lines)

def main():
    # JIS0208 Index (used by Shift_JIS, EUC-JP, ISO-2022-JP)
    print("Downloading jis0208 index...")
    jis0208_content = download_index(JIS0208_INDEX_URL)
    jis0208_entries = parse_index(jis0208_content)
    print(f"Parsed {len(jis0208_entries)} jis0208 entries")
    
    print("Generating src/japanese/jis0208_index.zig...")
    jis0208_code = generate_index_zig(
        jis0208_entries,
        "jis0208",
        "https://encoding.spec.whatwg.org/#index-jis0208",
        7939
    )
    with open('src/japanese/jis0208_index.zig', 'w') as f:
        f.write(jis0208_code)
    print(f"Generated jis0208_index.zig ({len(jis0208_code)} bytes)")
    
    # JIS0212 Index (used by EUC-JP only)
    print("\nDownloading jis0212 index...")
    jis0212_content = download_index(JIS0212_INDEX_URL)
    jis0212_entries = parse_index(jis0212_content)
    print(f"Parsed {len(jis0212_entries)} jis0212 entries")
    
    print("Generating src/japanese/jis0212_index.zig...")
    jis0212_code = generate_index_zig(
        jis0212_entries,
        "jis0212",
        "https://encoding.spec.whatwg.org/#index-jis0212",
        7939
    )
    with open('src/japanese/jis0212_index.zig', 'w') as f:
        f.write(jis0212_code)
    print(f"Generated jis0212_index.zig ({len(jis0212_code)} bytes)")
    
    # ISO-2022-JP Katakana Index (encoder only)
    print("\nDownloading iso-2022-jp-katakana index...")
    katakana_content = download_index(ISO2022JP_KATAKANA_INDEX_URL)
    katakana_entries = parse_index(katakana_content)
    print(f"Parsed {len(katakana_entries)} iso-2022-jp-katakana entries")
    
    print("Generating src/japanese/iso2022jp_katakana_index.zig...")
    katakana_code = generate_small_index_zig(
        katakana_entries,
        "iso-2022-jp-katakana",
        "https://encoding.spec.whatwg.org/#index-iso-2022-jp-katakana"
    )
    with open('src/japanese/iso2022jp_katakana_index.zig', 'w') as f:
        f.write(katakana_code)
    print(f"Generated iso2022jp_katakana_index.zig ({len(katakana_code)} bytes)")
    
    # EUC-KR Index
    print("\nDownloading euc-kr index...")
    euc_kr_content = download_index(EUC_KR_INDEX_URL)
    euc_kr_entries = parse_index(euc_kr_content)
    print(f"Parsed {len(euc_kr_entries)} euc-kr entries")
    
    print("Generating src/korean/euc_kr_index.zig...")
    euc_kr_code = generate_index_zig(
        euc_kr_entries,
        "euc-kr",
        "https://encoding.spec.whatwg.org/#index-euc-kr",
        17919
    )
    with open('src/korean/euc_kr_index.zig', 'w') as f:
        f.write(euc_kr_code)
    print(f"Generated euc_kr_index.zig ({len(euc_kr_code)} bytes)")
    
    print("\n✅ All index files generated successfully!")

if __name__ == '__main__':
    main()
