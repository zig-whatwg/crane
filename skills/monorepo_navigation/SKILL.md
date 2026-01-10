# Monorepo Navigation Skill

## Purpose

This skill provides guidance on navigating the WHATWG monorepo structure, finding spec implementations, and handling cross-spec dependencies.

---

## When to Use This Skill

Load this skill automatically when:
- Looking for implementations of other WHATWG specs
- Need to import or use functionality from another spec
- Checking if a dependency is implemented
- Understanding monorepo structure and organization
- Resolving cross-spec references in specifications

---

## Monorepo Structure

### Directory Layout

```
/Users/bcardarella/projects/whatwg/
├── src/                    # All spec implementations
│   ├── console/            # Console Standard
│   ├── encoding/           # Encoding Standard
│   ├── infra/              # Infra Standard (primitives)
│   ├── mimesniff/          # MIME Sniffing Standard
│   ├── streams/            # Streams Standard
│   ├── url/                # URL Standard
│   ├── webidl/             # WebIDL specification
│   └── root.zig            # Monorepo root module
├── specs/                  # Complete WHATWG specifications
│   ├── console.md
│   ├── encoding.md
│   ├── fetch.md
│   ├── infra.md
│   ├── mimesniff.md
│   ├── streams.md
│   ├── url.md
│   ├── webidl.md
│   └── ... (many more)
├── tests/                  # Test files
├── build.zig               # Build configuration
├── build.zig.zon           # Package dependencies
└── AGENTS.md               # Agent guidelines (this system)
```

---

## Finding Spec Implementations

### Pattern: Spec Name → Directory

**Convention:** Spec implementations are in `src/[spec-name]/`

| Spec Name | Directory | Status |
|-----------|-----------|--------|
| **URL** | `src/url/` | ✅ Implemented |
| **Encoding** | `src/encoding/` | ✅ Implemented |
| **Console** | `src/console/` | ✅ Implemented |
| **MIME Sniff** | `src/mimesniff/` | ✅ Implemented |
| **WebIDL** | `src/webidl/` | ✅ Implemented |
| **Infra** | `src/infra/` | ✅ Implemented |
| **Streams** | `src/streams/` | ✅ Implemented |
| **Fetch** | `src/fetch/` | ❌ Not implemented yet |
| **DOM** | `src/dom/` | ❌ Not implemented yet |

### Checking If a Spec Is Implemented

**Use the `list` tool or `bash` to check:**

```bash
# Check if URL is implemented
ls src/url/

# Check if Fetch is implemented
ls src/fetch/  # Will fail if not implemented
```

**Programmatic check in Zig:**
```zig
// Try to import the spec
const url = @import("url");  // Works if implemented

const fetch = @import("fetch");  // Compile error if not implemented
```

---

## Common Cross-Spec Dependencies

### Infra Standard (Most Common)

**Nearly every spec depends on Infra.**

**Location:** `src/infra/`

**Provides:**
- String operations (ASCII lowercase, split, etc.)
- Byte sequence operations
- Code point operations
- List operations (append, prepend, remove)
- Ordered map (key-value map with insertion order)

**Usage:**
```zig
const infra = @import("infra");

// ASCII lowercase
const lowercased = try infra.asciiLowercase(allocator, input);

// Append to list
try infra.append(list, item);

// Ordered map
var map = infra.OrderedMap([]const u8, u32).init(allocator);
try map.set("key", 42);
```

### WebIDL (Type System)

**Specs with Web APIs depend on WebIDL.**

**Location:** `src/webidl/`

**Provides:**
- Type conversions (DOMString, USVString, etc.)
- Interface definitions
- Type metadata

**Usage:**
```zig
const webidl = @import("webidl");

// Convert to USVString (replaces unpaired surrogates)
const usv_string = try webidl.toUSVString(allocator, input);
```

### URL Standard

**Used by:** Fetch, DOM, many others

**Location:** `src/url/`

**Provides:**
- URL parsing
- URL serialization
- Host parsing (IPv4, IPv6, domain)

**Usage:**
```zig
const url_mod = @import("url");

const url = try url_mod.URL.parse(allocator, "https://example.com/path");
defer url.deinit();
```

### Encoding Standard

**Used by:** Fetch, TextDecoder/TextEncoder APIs

**Location:** `src/encoding/`

**Provides:**
- UTF-8 encoding/decoding
- Legacy encoding support

**Usage:**
```zig
const encoding = @import("encoding");

const decoded = try encoding.decode(allocator, bytes, .utf8);
defer allocator.free(decoded);
```

### Streams Standard

**Used by:** Fetch, Response bodies, File API

**Location:** `src/streams/`

**Provides:**
- ReadableStream
- WritableStream
- TransformStream

**Usage:**
```zig
const streams = @import("streams");

var stream = try streams.ReadableStream.init(allocator, .{
    .pull = pullFn,
});
defer stream.deinit();
```

---

## Dependency Resolution Workflow

### Step 1: Identify Dependency

**From spec text:**
> "Let result be an empty list."

**Dependency:** Infra Standard (lists)

**From spec text:**
> "Let url be the result of parsing input."

**Dependency:** URL Standard

### Step 2: Check If Implemented

**Use list tool:**
```bash
ls src/infra/    # Check if Infra is implemented
ls src/url/      # Check if URL is implemented
```

**Or check imports in existing code:**
```bash
rg "@import\(\"infra\"\)" src/
rg "@import\(\"url\"\)" src/
```

### Step 3A: If Implemented → Use It

**Import the module:**
```zig
const infra = @import("infra");
const url = @import("url");
```

**Use the functionality:**
```zig
// Infra list operations
var list = std.ArrayList(Item).init(allocator);
try infra.append(&list, item);

// URL parsing
const parsed_url = try url.URL.parse(allocator, input);
```

### Step 3B: If NOT Implemented → Create Mock

**Use the `dependency_mocking` skill** to create a temporary mock.

**Example:**
```zig
/// TEMPORARY MOCK: This is a mock implementation of Fetch Standard.
/// TODO: Replace with actual implementation from src/fetch/ when available.
/// 
/// This mock implements just enough of Fetch to unblock Streams testing.
/// It does NOT fully implement the WHATWG Fetch specification.
pub const MockFetch = struct {
    pub fn fetch(allocator: Allocator, url: []const u8) !Response {
        // Minimal mock implementation
        return Response{ .status = 200 };
    }
};
```

---

## Import Patterns

### Standard Import Pattern

```zig
// Import another spec module
const infra = @import("infra");
const url = @import("url");
const encoding = @import("encoding");
const webidl = @import("webidl");

// Use qualified names to avoid conflicts
const lowercase = try infra.asciiLowercase(allocator, input);
const parsed = try url.URL.parse(allocator, input);
```

### Selective Import Pattern

```zig
// Import specific types
const URL = @import("url").URL;
const OrderedMap = @import("infra").OrderedMap;

// Use directly
const url = try URL.parse(allocator, input);
var map = OrderedMap([]const u8, u32).init(allocator);
```

### Internal Module Imports

```zig
// Within a spec, import other modules from same spec
const parser = @import("parser.zig");
const serializer = @import("serializer.zig");
const types = @import("types.zig");
```

---

## Discovering Spec Structure

### Explore a Spec Directory

**List files in a spec:**
```bash
ls src/url/
```

Typical structure:
```
src/url/
├── parser.zig          # Main parsing logic
├── serializer.zig      # Serialization logic
├── host.zig            # Host parsing (IPv4, IPv6, domain)
├── types.zig           # URL record and types
└── root.zig            # Public API (exports everything)
```

### Find Main Entry Point

**Pattern:** `root.zig` is usually the main entry point

```bash
cat src/url/root.zig
```

This file typically exports the public API:
```zig
pub const URL = @import("types.zig").URL;
pub const parse = @import("parser.zig").parse;
pub const serialize = @import("serializer.zig").serialize;
```

### Search for Specific Functionality

```bash
# Find where URL parsing is implemented
rg "pub fn parse" src/url/

# Find where encoding happens
rg "pub fn encode" src/encoding/

# Find Infra list operations
rg "pub fn append" src/infra/
```

---

## Cross-Spec Reference Examples

### Example 1: URL Uses Infra

**Spec text (URL Standard):**
> "Let segments be an empty list."

**Implementation:**
```zig
const infra = @import("infra");

pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // "Let segments be an empty list"
    var segments = std.ArrayList([]const u8).init(allocator);
    defer segments.deinit();
    
    // ... (parsing logic)
}
```

### Example 2: Fetch Uses URL and Streams

**Spec text (Fetch Standard):**
> "Let url be the result of parsing input with base."
> "Let body be a new ReadableStream."

**Implementation:**
```zig
const url_mod = @import("url");
const streams = @import("streams");

pub fn fetch(allocator: Allocator, input: []const u8, base: ?url_mod.URL) !Response {
    // "Let url be the result of parsing input with base"
    const url = try url_mod.URL.parse(allocator, input, base);
    defer url.deinit();
    
    // "Let body be a new ReadableStream"
    var body = try streams.ReadableStream.init(allocator, .{
        .pull = fetchPullFn,
    });
    
    return Response{ .url = url, .body = body };
}
```

### Example 3: Encoding Uses Infra Code Points

**Spec text (Encoding Standard):**
> "For each code point in input..."

**Implementation:**
```zig
const infra = @import("infra");

pub fn encode(allocator: Allocator, input: []const u8) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    errdefer output.deinit();
    
    // "For each code point in input"
    var iter = infra.CodePointIterator.init(input);
    while (iter.next()) |code_point| {
        // Process code point
        try appendCodePoint(&output, code_point);
    }
    
    return output.toOwnedSlice();
}
```

---

## Troubleshooting

### Issue: "Cannot find module 'X'"

**Cause:** The spec is not implemented yet.

**Solution:**
1. Check if it exists: `ls src/[spec-name]/`
2. If missing, use `dependency_mocking` skill to create temporary mock
3. Create bd issue to track implementation: `bd create "Implement [Spec Name]" -t feature -p 2 --json`

### Issue: "Module 'X' has no export 'Y'"

**Cause:** The specific function/type doesn't exist yet in the implementation.

**Solution:**
1. Check what's exported: `rg "pub const|pub fn" src/[spec-name]/root.zig`
2. If missing, implement it or create a mock
3. Create bd issue: `bd create "Implement [Function] in [Spec]" -t feature -p 2 --json`

### Issue: "Circular dependency between X and Y"

**Cause:** Two specs reference each other.

**Solution:**
1. Check WHATWG spec for dependency direction
2. Usually one spec provides interfaces, another implements
3. May need to refactor to break cycle (use dependency injection or callbacks)

---

## Best Practices

1. **Always use qualified imports** - `const infra = @import("infra")` instead of polluting namespace
2. **Check implementation before using** - Use `ls src/[spec]/` to verify
3. **Read root.zig first** - Understand public API before diving into internals
4. **Follow dependency chain** - If X depends on Y, implement Y first
5. **Create mocks for unimplemented deps** - Don't let missing deps block progress
6. **Track missing implementations** - Use bd to track what needs to be implemented

---

## Quick Reference

### Implemented Specs

```
src/console/        ✅ Console Standard
src/encoding/       ✅ Encoding Standard
src/infra/          ✅ Infra Standard (primitives for all specs)
src/mimesniff/      ✅ MIME Sniffing Standard
src/streams/        ✅ Streams Standard
src/url/            ✅ URL Standard
src/webidl/         ✅ WebIDL (type system)
```

### Common Dependency Patterns

```
URL → Infra, WebIDL
Encoding → Infra, WebIDL
Streams → Infra, WebIDL
Fetch → URL, Streams, Infra, WebIDL, MIME Sniff
Console → WebIDL
```

### Import Template

```zig
// Import dependencies
const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");

// Use qualified names
const lowercase = try infra.asciiLowercase(allocator, input);
const usv = try webidl.toUSVString(allocator, text);
```

---

**Remember**: This is a monorepo. All specs are in `src/`. Use imports to share code across specs. Create mocks when dependencies aren't ready yet.
