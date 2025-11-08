#!/usr/bin/env python3
"""Generate Encoding constant definitions for encoding.zig"""

# List of all 28 single-byte encodings
# Format: (whatwg_name, CONST_NAME, zig_module_name)
encodings = [
    ("ibm866", "IBM866", "ibm866"),
    ("iso-8859-2", "ISO_8859_2", "iso_8859_2"),
    ("iso-8859-3", "ISO_8859_3", "iso_8859_3"),
    ("iso-8859-4", "ISO_8859_4", "iso_8859_4"),
    ("iso-8859-5", "ISO_8859_5", "iso_8859_5"),
    ("iso-8859-6", "ISO_8859_6", "iso_8859_6"),
    ("iso-8859-7", "ISO_8859_7", "iso_8859_7"),
    ("iso-8859-8", "ISO_8859_8", "iso_8859_8"),
    ("iso-8859-8-i", "ISO_8859_8_I", "iso_8859_8_i"),
    ("iso-8859-10", "ISO_8859_10", "iso_8859_10"),
    ("iso-8859-13", "ISO_8859_13", "iso_8859_13"),
    ("iso-8859-14", "ISO_8859_14", "iso_8859_14"),
    ("iso-8859-15", "ISO_8859_15", "iso_8859_15"),
    ("iso-8859-16", "ISO_8859_16", "iso_8859_16"),
    ("koi8-r", "KOI8_R", "koi8_r"),
    ("koi8-u", "KOI8_U", "koi8_u"),
    ("macintosh", "MACINTOSH", "macintosh"),
    ("windows-874", "WINDOWS_874", "windows_874"),
    ("windows-1250", "WINDOWS_1250", "windows_1250"),
    ("windows-1251", "WINDOWS_1251", "windows_1251"),
    ("windows-1252", "WINDOWS_1252", "windows_1252"),
    ("windows-1253", "WINDOWS_1253", "windows_1253"),
    ("windows-1254", "WINDOWS_1254", "windows_1254"),
    ("windows-1255", "WINDOWS_1255", "windows_1255"),
    ("windows-1256", "WINDOWS_1256", "windows_1256"),
    ("windows-1257", "WINDOWS_1257", "windows_1257"),
    ("windows-1258", "WINDOWS_1258", "windows_1258"),
    ("x-mac-cyrillic", "X_MAC_CYRILLIC", "x_mac_cyrillic"),
]

print("// Single-byte encoding instances")
for whatwg, const, zig_mod in encodings:
    print(f"""pub const {const}: Encoding = .{{
    .name = "{whatwg}",
    .whatwg_name = "{whatwg}",
    .decode_fn = single_byte.decode,
    .encode_fn = single_byte.encode,
    .single_byte_index = single_byte.{zig_mod}.INDEX,
}};
""")

print("\n// ALL_ENCODINGS array")
print("pub const ALL_ENCODINGS = [_]*const Encoding{")
print("    &UTF_8,")
for _, const, _ in encodings:
    print(f"    &{const},")
print("};")
