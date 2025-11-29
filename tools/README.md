# Build Tools

This directory contains build-time code generation tools and utilities for WHATWG spec implementations.

## Available Tools

### Encoding (`tools/encoding/`)

Python scripts for generating encoding lookup tables from WHATWG data files:

- **`generate_encoding.py`** - Generate encoding lookup tables
- **`generate_encoding_defs.py`** - Generate encoding definitions
- **`generate_gb18030.py`** - Generate GB18030 specific tables
- **`generate_japanese_korean.py`** - Generate Japanese/Korean encoding tables
- **`generate_labels.py`** - Generate encoding label mappings
- **`pre-commit.sh`** - Pre-commit hook for encoding changes
- **`setup-git-hooks.sh`** - Setup git hooks for encoding development

**Usage**:
```bash
# Run Python generators
python tools/encoding/generate_encoding.py
python tools/encoding/generate_gb18030.py
```

### URL (`tools/url/`)

Zig and shell tools for URL-related code generation:

- **`generate_idna_tables.zig`** - Generate IDNA Unicode lookup tables
- **`generate_psl.zig`** - Generate Public Suffix List data
- **`download_unicode_data.sh`** - Download Unicode data files
- **`tests/`** - Tests for URL tools
  - `test_simple.zig` - Simple tool tests
  - `test_xn_decode.zig` - Punycode decode tests

**Usage**:
```bash
# Download Unicode data
bash tools/url/download_unicode_data.sh

# Generate IDNA tables
zig run tools/url/generate_idna_tables.zig

# Generate PSL data
zig run tools/url/generate_psl.zig

# Run tool tests
zig test tools/url/tests/test_simple.zig
```

## Tool Development

Tools are standalone executables that run at build-time. They are NOT part of the runtime library.

Example tool structure:

```zig
// tools/url/generate_idna_tables.zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read data file
    const data = try std.fs.cwd().readFileAlloc(
        allocator,
        "data/url/idna/UnicodeData.txt",
        10 * 1024 * 1024,
    );
    defer allocator.free(data);

    // Parse and generate Zig lookup table
    const output = try generateLookupTable(allocator, data);
    defer allocator.free(output);

    // Write to src/
    try std.fs.cwd().writeFile(
        "src/url/idna/unicode_data.zig",
        output,
    );
}
```

## Adding New Tools

1. Create tool source file in appropriate subdirectory
2. Document usage in this README
3. Add build step to `build.zig` if needed (optional)
4. Test the tool with sample data
