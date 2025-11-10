# WHATWG Specification Implementation Skill

## Purpose

This skill provides **comprehensive guidance for implementing WHATWG specifications in Zig**: from reading the spec to writing spec-compliant Zig code.

---

## When to Use This Skill

Load this skill automatically when:
- Implementing features from any WHATWG specification
- Looking up specific algorithm steps or sections
- Mapping WHATWG spec concepts to Zig implementations
- Understanding data structures, state machines, or parsers
- Verifying correct implementation behavior
- Checking interface definitions and method signatures

---

## What This Skill Provides

**Integrated workflow for WHATWG spec implementation:**

1. **Spec Navigation** - Find and read WHATWG algorithms
2. **Context Detection** - Automatically identify which spec you're working on
3. **Type Mapping** - Map spec types to idiomatic Zig types
4. **Implementation Patterns** - Complete examples with numbered steps matching spec
5. **Cross-Spec Dependencies** - Handle dependencies between specs
6. **Spec Compliance** - Ensure implementation matches specification exactly

---

# Part 1: Reading WHATWG Specifications

## Critical Rule: Always Load Complete Spec Sections

**NEVER rely on grep fragments or partial algorithm text.**

When implementing any WHATWG feature:

1. **Detect context** - Identify which spec you're implementing
2. **Load the complete algorithm** from the relevant spec file
3. **Read the full algorithm** with all steps, context, and cross-references
4. **Check cross-spec dependencies** - Algorithms often reference other WHATWG specs
5. **Understand edge cases** - Every algorithm has corner cases and error conditions

---

## Context Detection

**This skill automatically detects which spec you're working on from:**

### File Path Detection

```
src/url/parser.zig        → URL Standard
src/encoding/decoder.zig  → Encoding Standard
src/streams/readable.zig  → Streams Standard
src/infra/strings.zig     → Infra Standard
src/console/logger.zig    → Console Standard
src/mimesniff/sniff.zig   → MIME Sniffing Standard
src/webidl/types.zig      → WebIDL
```

### Import Statement Detection

```zig
@import("url")        → URL Standard
@import("encoding")   → Encoding Standard
@import("infra")      → Infra Standard
@import("webidl")     → WebIDL
@import("streams")    → Streams Standard
```

### Manual Context

If context cannot be detected, the user will specify which spec they're implementing.

---

## Available Specifications

**Complete specifications are in `specs/` directory:**

| Spec | File | Status | Key Features |
|------|------|--------|--------------|
| **URL** | `specs/url.md` | ✅ Implemented | Parsing, serialization, host parsing |
| **Encoding** | `specs/encoding.md` | ✅ Implemented | UTF-8, legacy encodings |
| **Console** | `specs/console.md` | ✅ Implemented | Logging APIs |
| **MIME Sniff** | `specs/mimesniff.md` | ✅ Implemented | MIME type detection |
| **WebIDL** | `specs/webidl.md` | ✅ Implemented | Type system, conversions |
| **Infra** | `specs/infra.md` | ✅ Implemented | Primitives (lists, strings, bytes) |
| **Streams** | `specs/streams.md` | ✅ Implemented | ReadableStream, WritableStream |
| **Fetch** | `specs/fetch.md` | Available | HTTP requests |
| **DOM** | `specs/dom.md` | Available | DOM APIs |
| **XHR** | `specs/xhr.md` | Available | XMLHttpRequest |

---

## Workflow: Spec to Implementation

### Step 1: Identify Context

**Automatic detection:**
- Working in `src/url/` → URL Standard
- Working in `src/encoding/` → Encoding Standard
- Working in `src/streams/` → Streams Standard

**Manual context:**
- User says "I'm implementing URL parsing" → URL Standard
- User says "I need to decode UTF-8" → Encoding Standard

### Step 2: Locate the Spec File

**Pattern:** `specs/[spec-name].md`

```bash
# URL Standard
specs/url.md

# Encoding Standard
specs/encoding.md

# Streams Standard
specs/streams.md

# Infra Standard (used by almost all specs)
specs/infra.md
```

### Step 3: Find the Algorithm

**Use ripgrep (rg) to find algorithms:**

```bash
# Find URL parsing algorithm
rg -n "basic URL parser" specs/url.md

# Find encoding decoder
rg -n "decode" specs/encoding.md

# Find stream reading
rg -n "read from a readable stream" specs/streams.md

# Find Infra list operations
rg -n "append to a list" specs/infra.md
```

**Common algorithm patterns:**
- "To [operation name]" - Algorithm definitions
- "The [operation name] algorithm" - Formal algorithm sections
- "[Type] object's [operation]" - Object method algorithms

### Step 4: Load Complete Section

**Read the file** with the `read` tool:

```
read("specs/url.md", offset=<start_line>, limit=<line_count>)
```

**Find section boundaries:**
- Load from algorithm header to the next algorithm or section
- Include all numbered steps, notes, and examples
- Don't stop at the first step - read the ENTIRE algorithm

### Step 5: Understand Cross-Spec References

**WHATWG specs frequently reference each other:**

**Common patterns:**
- "Let result be an empty list" → Infra Standard (§4 Lists)
- "Let url be a new URL" → URL Standard
- "Encode using UTF-8" → Encoding Standard
- "Return a new promise" → WebIDL

**When you see cross-spec references:**
1. Note the referenced spec
2. Use `monorepo_navigation` skill to find implementation in `src/`
3. If not implemented, use `dependency_mocking` skill to create temporary mock

---

## Spec Terminology

| Spec Term | Meaning |
|-----------|---------|
| **Let** | Variable assignment |
| **Set** | Modify existing variable or property |
| **Return** | Return value from algorithm |
| **Throw** | Raise an exception |
| **Assert** | Invariant that should always be true |
| **If...then...otherwise** | Conditional logic |
| **For each...in** | Loop over collection |
| **While** | Loop with condition |
| **Abort these steps** | Early return (stop algorithm) |
| **Continue** | Skip to next iteration |

---

# Part 2: WHATWG Type Mapping to Zig

## Core Principle

Map WHATWG spec types to **idiomatic Zig** types that preserve spec semantics while enabling efficient implementation.

## General Mapping Patterns

| Spec Concept | Zig Type | Notes |
|--------------|----------|-------|
| **String** | `[]const u8` | UTF-8 encoded |
| **Byte sequence** | `[]const u8` | Raw bytes |
| **List** | `std.ArrayList(T)` | Dynamic array |
| **Ordered map** | Custom struct | Preserves insertion order |
| **Boolean** | `bool` | Direct mapping |
| **Integer** | `i32`, `u32`, `usize` | Context-dependent |
| **Float** | `f64` | Usually f64 for spec compliance |
| **Enum/State** | `enum` | For spec-defined states |
| **Record/Struct** | `struct` | For spec-defined types |
| **Optional** | `?T` | For "X or null" |

---

## Context-Specific Type Mapping

### URL Standard Types

| URL Spec Type | Zig Type | Example |
|---------------|----------|---------|
| URL record | `struct` | `pub const URL = struct { ... }` |
| Host | `union(enum)` | domain, IPv4, IPv6, opaque |
| Scheme | `[]const u8` | "https", "http", "file" |
| Port | `?u16` | Optional port (0-65535 or null) |
| Path | `[]const u8` | "/path/to/resource" |

**Example:**
```zig
/// URL record from URL Standard §4.
pub const URL = struct {
    scheme: []const u8,
    username: []const u8,
    password: []const u8,
    host: ?Host,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,
    allocator: Allocator,
    
    pub fn deinit(self: *URL) void {
        self.allocator.free(self.scheme);
        self.allocator.free(self.username);
        self.allocator.free(self.password);
        if (self.host) |host| host.deinit(self.allocator);
        self.allocator.free(self.path);
        if (self.query) |q| self.allocator.free(q);
        if (self.fragment) |f| self.allocator.free(f);
    }
};

/// Host from URL Standard §4.2.
pub const Host = union(enum) {
    domain: []const u8,
    ipv4: u32,
    ipv6: [8]u16,
    opaque: []const u8,
    
    pub fn deinit(self: Host, allocator: Allocator) void {
        switch (self) {
            .domain, .opaque => |s| allocator.free(s),
            .ipv4, .ipv6 => {},
        }
    }
};
```

### Encoding Standard Types

| Encoding Spec Type | Zig Type | Example |
|--------------------|----------|---------|
| Decoder | `struct` | Stateful decoder |
| Encoder | `struct` | Stateful encoder |
| Code point | `u21` | Unicode code point (0-0x10FFFF) |
| Byte | `u8` | Single byte |

**Example:**
```zig
/// Decoder from Encoding Standard.
pub const Decoder = struct {
    encoding: Encoding,
    state: DecoderState,
    allocator: Allocator,
    
    pub fn decode(self: *Decoder, input: []const u8) ![]const u8 {
        var output = std.ArrayList(u8).init(self.allocator);
        errdefer output.deinit();
        
        for (input) |byte| {
            const result = try self.processByte(byte);
            if (result.output) |code_point| {
                try appendCodePoint(&output, code_point);
            }
        }
        
        return output.toOwnedSlice();
    }
};
```

### Streams Standard Types

| Streams Spec Type | Zig Type | Example |
|-------------------|----------|---------|
| ReadableStream | `struct` | Stream state + queue |
| WritableStream | `struct` | Stream state + queue |
| Stream state | `enum` | readable/closed/errored |
| Reader/Writer | `struct` | Locks the stream |

**Example:**
```zig
/// ReadableStream from Streams Standard §3.
pub const ReadableStream = struct {
    state: State,
    reader: ?*Reader,
    queue: std.ArrayList([]const u8),
    allocator: Allocator,
    
    pub const State = enum {
        readable,
        closed,
        errored,
    };
    
    pub fn getReader(self: *ReadableStream) !*Reader {
        if (self.isLocked()) {
            return error.TypeError;
        }
        
        const reader = try self.allocator.create(Reader);
        errdefer self.allocator.destroy(reader);
        
        reader.* = Reader{
            .stream = self,
            .allocator = self.allocator,
        };
        self.reader = reader;
        
        return reader;
    }
};
```

### Infra Standard Types

| Infra Spec Type | Zig Type | Example |
|-----------------|----------|---------|
| List | `std.ArrayList(T)` | Dynamic array |
| Ordered map | Custom struct | Insertion-order map |
| Byte sequence | `[]const u8` | Raw bytes |
| Code point | `u21` | Unicode code point |
| String | `[]const u8` | UTF-8 encoded |

**Example:**
```zig
/// Ordered map from Infra Standard §7.
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        entries: std.ArrayList(Entry),
        allocator: Allocator,
        
        const Entry = struct {
            key: K,
            value: V,
        };
        
        const Self = @This();
        
        pub fn get(self: Self, key: K) ?V {
            for (self.entries.items) |entry| {
                if (std.meta.eql(entry.key, key)) {
                    return entry.value;
                }
            }
            return null;
        }
        
        pub fn set(self: *Self, key: K, value: V) !void {
            for (self.entries.items, 0..) |entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    self.entries.items[i].value = value;
                    return;
                }
            }
            try self.entries.append(.{ .key = key, .value = value });
        }
    };
}
```

---

# Part 3: Algorithm Implementation

## Step-by-Step Implementation Pattern

**Spec Algorithm:**
```
To parse a URL, given a string input:

1. Let url be a new URL.
2. Let state be scheme start state.
3. Set url's scheme to the empty string.
4. For each code point c in input:
   a. If state is scheme start state:
      i. If c is an ASCII alpha, ...
      ii. Otherwise, ...
5. Return url.
```

**Zig Implementation:**
```zig
/// Parse a URL string into a URL record.
///
/// Implements WHATWG URL "parse a URL" per §4.1.
///
/// ## Spec Reference
/// https://url.spec.whatwg.org/#concept-url-parser
///
/// ## Algorithm (URL §4.1)
/// 1. Let url be a new URL.
/// 2. Let state be scheme start state.
/// 3. Set url's scheme to the empty string.
/// 4. For each code point c in input...
/// 5. Return url.
///
/// ## Parameters
/// - `allocator`: Memory allocator
/// - `input`: URL string to parse
///
/// ## Returns
/// Parsed URL record, or error if invalid.
pub fn parse(allocator: Allocator, input: []const u8) !URL {
    // 1. Let url be a new URL
    var url = URL.init(allocator);
    errdefer url.deinit();
    
    // 2. Let state be scheme start state
    var state = State.scheme_start;
    
    // 3. Set url's scheme to the empty string
    url.scheme = "";
    
    // 4. For each code point c in input
    var iter = CodePointIterator.init(input);
    while (iter.next()) |c| {
        // a. If state is scheme start state
        if (state == .scheme_start) {
            // i. If c is an ASCII alpha
            if (isAsciiAlpha(c)) {
                // ... (implementation)
            }
            // ii. Otherwise
            else {
                // ... (implementation)
            }
        }
    }
    
    // 5. Return url
    return url;
}
```

**Key Pattern:**
- **Numbered comments** match spec steps exactly
- **Preserve spec structure** (nested if statements, loops)
- **Use spec terminology** in variable names
- **Document with spec reference**

---

## State Machine Implementation

Many WHATWG specs use state machines (URL parsing, encoding, stream operations).

**Pattern:**
```zig
pub const State = enum {
    scheme_start,
    scheme,
    no_scheme,
    special_relative_or_authority,
    // ... (all states from spec)
};

pub fn parse(allocator: Allocator, input: []const u8) !URL {
    var url = URL.init(allocator);
    errdefer url.deinit();
    
    var state = State.scheme_start;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // Main state machine loop
    var iter = CodePointIterator.init(input);
    while (iter.next()) |c| {
        switch (state) {
            .scheme_start => {
                if (isAsciiAlpha(c)) {
                    try buffer.append(toLower(c));
                    state = .scheme;
                } else {
                    state = .no_scheme;
                    iter.rewind();
                }
            },
            .scheme => {
                if (isAsciiAlphanumeric(c) or c == '+' or c == '-' or c == '.') {
                    try buffer.append(toLower(c));
                } else if (c == ':') {
                    url.scheme = try buffer.toOwnedSlice();
                    state = .special_relative_or_authority;
                } else {
                    return error.InvalidScheme;
                }
            },
            // ... (all other states)
        }
    }
    
    return url;
}
```

---

## Documentation Pattern for Spec Implementations

**Every public function implementing a spec algorithm MUST have:**

```zig
/// [Brief one-line description].
///
/// Implements WHATWG [Spec Name] "[algorithm name]" per §X.Y.
///
/// [Detailed explanation]
///
/// ## Spec Reference
///
/// https://[spec].spec.whatwg.org/#[anchor]
///
/// ## Algorithm ([Spec Name] §X.Y)
///
/// [Paste the complete algorithm from the spec, or summarize steps]
///
/// ## Parameters
///
/// - `param1`: Description
/// - `param2`: Description
///
/// ## Returns
///
/// Description of return value
///
/// ## Errors
///
/// - `error.ErrorName`: When this error occurs
///
/// ## Example
///
/// ```zig
/// const result = try functionName(allocator, input);
/// defer result.deinit();
/// ```
pub fn functionName(allocator: Allocator, input: []const u8) !Result {
    // Implementation with numbered comments matching spec
}
```

---

# Part 4: Spec-Specific Guidance

## URL Standard

**Key sections:**
- §4 URL parsing - The basic URL parser (state machine)
- §4.3 Host parsing - IPv4, IPv6, domain, opaque host
- §4.5 URL serialization - Converting URL to string

**Common algorithms:**
- "basic URL parser" - Main parsing algorithm
- "host parser" - Parse host component
- "URL serializer" - Convert URL to string

**Search patterns:**
```bash
rg -n "basic URL parser" specs/url.md
rg -n "host parser" specs/url.md
rg -n "URL serializer" specs/url.md
```

## Encoding Standard

**Key sections:**
- §4 Encodings - UTF-8, legacy encodings
- §5 API - Decoder and encoder interfaces
- §8 Legacy encodings - ISO-8859-1, Shift_JIS, etc.

**Common algorithms:**
- "decode" - Convert bytes to string
- "encode" - Convert string to bytes
- "UTF-8 decode" - UTF-8 decoding algorithm

**Search patterns:**
```bash
rg -n "UTF-8 decode" specs/encoding.md
rg -n "encode" specs/encoding.md
```

## Streams Standard

**Key sections:**
- §3 Readable streams - ReadableStream, readers, controllers
- §4 Writable streams - WritableStream, writers, controllers
- §5 Transform streams - TransformStream
- §6 Queuing strategies - Buffering and backpressure

**Common algorithms:**
- "read from a readable stream" - Reading chunks
- "write to a writable stream" - Writing chunks
- "pipe to" - Connecting streams

**Search patterns:**
```bash
rg -n "read from a readable stream" specs/streams.md
rg -n "write to a writable stream" specs/streams.md
rg -n "pipe to" specs/streams.md
```

## Infra Standard

**Key sections:**
- §2 Bytes - Byte sequences and operations
- §3 Code points - Unicode code point operations
- §4 Lists - List/array operations
- §5 Strings - String operations
- §7 Ordered maps - Key-value maps with insertion order

**Common algorithms:**
- "append to a list" - Add item to list
- "ASCII lowercase" - Lowercase ASCII string
- "split a string" - String splitting

**Search patterns:**
```bash
rg -n "append to a list" specs/infra.md
rg -n "ASCII lowercase" specs/infra.md
rg -n "split a string" specs/infra.md
```

---

# Part 5: Cross-Spec Dependencies

## Common Dependency Patterns

**Infra** - Used by nearly all specs:
- String operations (ASCII lowercase, split, strip)
- Byte operations
- List operations (append, prepend, remove)
- Ordered map (insertion-order key-value map)

**WebIDL** - Used by specs with Web APIs:
- Type conversions (DOMString, USVString, etc.)
- Interface definitions

**URL** - Used by Fetch, DOM, and many others:
- URL parsing
- URL serialization
- Host parsing

**Encoding** - Used by text processing specs:
- UTF-8 encoding/decoding
- Legacy encoding support

**Streams** - Used by Fetch, File API, etc.:
- ReadableStream
- WritableStream
- TransformStream

## Handling Dependencies

**When spec references another spec:**

1. **Identify dependency** - Note which spec is referenced
2. **Check if implemented** - Use `ls src/[spec-name]/`
3. **Import if available** - `@import("spec-name")`
4. **Mock if unavailable** - Use `dependency_mocking` skill

**Example:**
```zig
// Spec says: "Let result be an empty list"
// This references Infra Standard

const infra = @import("infra");

pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // "Let segments be an empty list"
    var segments = std.ArrayList([]const u8).init(allocator);
    defer segments.deinit();
    
    // Use Infra operations if needed
    // try infra.append(&segments, segment);
}
```

---

# Part 6: WebIDL Interface Naming Conventions

## Critical Rules for WebIDL Interfaces

**When implementing WebIDL interfaces, namespaces, mixins, or dictionaries:**

### File Naming: PascalCase

**All WebIDL interface files MUST use PascalCase naming:**

```
❌ WRONG:
webidl/src/encoding/text_decoder.zig
webidl/src/console/console.zig
webidl/src/dom/abort_controller.zig

✅ CORRECT:
webidl/src/encoding/TextDecoder.zig
webidl/src/console/Console.zig
webidl/src/dom/AbortController.zig
```

**This applies to:**
- **Interfaces**: `TextDecoder.zig`, `ReadableStream.zig`, `EventTarget.zig`
- **Namespaces**: `Console.zig`
- **Mixins**: `TextDecoderCommon.zig`, `EventTargetMixin.zig`
- **Dictionaries**: `TextDecoderOptions.zig`, `ReadableStreamReadResult.zig`

**Rationale:** File names should match the type they define for clarity and consistency.

### Attribute Naming: camelCase

**All WebIDL interface attributes MUST use camelCase:**

```zig
❌ WRONG:
pub const TextDecoder = webidl.interface(struct {
    encoding_name: []const u8,      // ❌ snake_case
    do_not_flush: bool,              // ❌ snake_case
    ignore_bom: bool,                // ❌ snake_case
    reusable_utf16_buf: ?[]u16,     // ❌ snake_case
});

✅ CORRECT:
pub const TextDecoder = webidl.interface(struct {
    encodingName: []const u8,                // ✅ camelCase
    doNotFlush: bool,                        // ✅ camelCase
    ignoreBOM: bool,                         // ✅ camelCase
    reusableUtf16Buffer: ?webidl.DOMString, // ✅ camelCase + WebIDL type
});
```

**Rationale:** WebIDL attributes use camelCase per JavaScript naming conventions.

### Method Naming: camelCase (No Prefixes)

**WebIDL methods MUST use camelCase without prefixes:**

```zig
❌ WRONG:
pub fn call_decode(...) ![]const u8 { }    // ❌ call_ prefix
pub fn call_encode(...) ![]const u8 { }    // ❌ call_ prefix
pub fn get_encoding() []const u8 { }       // ❌ get_ prefix for getter
pub fn call_log(...) void { }              // ❌ call_ prefix

✅ CORRECT:
pub fn decode(...) ![]const u8 { }         // ✅ No prefix
pub fn encode(...) ![]const u8 { }         // ✅ No prefix
pub fn encoding() []const u8 { }           // ✅ No prefix (readonly attribute)
pub fn log(...) void { }                   // ✅ No prefix
```

**Exception for getters:** Readonly attributes may use method names matching the attribute:
- `readonly attribute DOMString encoding` → `pub fn encoding() []const u8`
- `readonly attribute boolean fatal` → `pub fn getFatal() bool` (or just expose field)

**Rationale:** WebIDL methods map directly to JavaScript methods, which use camelCase without prefixes.

### Type Usage: WebIDL/Infra Types

**ALWAYS use WebIDL/Infra type aliases instead of raw Zig primitives:**

```zig
❌ WRONG (raw Zig types):
pub const TextDecoder = webidl.interface(struct {
    fatal: bool,                   // ❌ Use webidl.boolean
    reusable_buf: ?[]u16,          // ❌ Use webidl.DOMString
    encoding_name: []const u8,     // ❌ For WebIDL string, consider DOMString
});

✅ CORRECT (WebIDL types):
pub const TextDecoder = webidl.interface(struct {
    fatal: webidl.boolean,                 // ✅ WebIDL type
    reusableBuffer: ?webidl.DOMString,     // ✅ WebIDL type (UTF-16)
    encodingName: []const u8,              // ✅ OK for internal UTF-8
});
```

**Available WebIDL types** (from `src/webidl/root.zig`):

```zig
// Primitives
webidl.boolean           // bool
webidl.long              // i32
webidl.@"unsigned long"  // u32
webidl.double            // f64
webidl.any               // JSValue

// Strings
webidl.DOMString         // UTF-16 string (infra.String)
webidl.USVString         // UTF-16 scalar values (infra.String)
webidl.ByteString        // Latin-1 string ([]const u8)

// Complex types
webidl.JSValue           // JavaScript value union
webidl.JSObject          // JavaScript object
webidl.Nullable(T)       // T or null
webidl.Sequence(T)       // Array of T
webidl.Record(K, V)      // Map/dictionary
```

**When to use WebIDL types vs Zig primitives:**

| Use Case | Type Choice | Example |
|----------|-------------|---------|
| **WebIDL interface parameter** | WebIDL type | `fn decode(input: webidl.ByteString)` |
| **WebIDL interface attribute** | WebIDL type | `fatal: webidl.boolean` |
| **WebIDL interface return** | WebIDL type | `fn encode() !webidl.ByteString` |
| **Internal implementation** | Zig primitive OK | `var index: usize = 0;` |
| **Spec algorithm variable** | Zig primitive OK | `var found: bool = false;` |

**Key principle:** Use WebIDL types at API boundaries, Zig primitives for internal implementation.

### Complete Example

**BEFORE (incorrect naming):**
```zig
// ❌ webidl/src/encoding/text_decoder.zig

const TextDecoderOptions = @import("text_decoder_options.zig").TextDecoderOptions;

pub const TextDecoder = webidl.interface(struct {
    encoding_name: []const u8,     // ❌ snake_case
    do_not_flush: bool,             // ❌ snake_case, raw type
    ignore_bom: bool,               // ❌ snake_case, raw type
    
    pub fn get_encoding(self: *const TextDecoder) []const u8 {  // ❌ get_ prefix
        return self.encoding_name;
    }
    
    pub fn call_decode(                 // ❌ call_ prefix
        self: *TextDecoder,
        input: []const u8,
        options: TextDecodeOptions,
    ) ![]const u8 {
        // ...
    }
});
```

**AFTER (correct naming):**
```zig
// ✅ webidl/src/encoding/TextDecoder.zig

const TextDecoderOptions = @import("TextDecoderOptions.zig").TextDecoderOptions;

pub const TextDecoder = webidl.interface(struct {
    encodingName: []const u8,              // ✅ camelCase
    doNotFlush: webidl.boolean,            // ✅ camelCase + WebIDL type
    ignoreBOM: webidl.boolean,             // ✅ camelCase + WebIDL type
    
    pub fn encoding(self: *const TextDecoder) []const u8 {  // ✅ No prefix
        return self.encodingName;
    }
    
    pub fn decode(                          // ✅ No prefix
        self: *TextDecoder,
        input: []const u8,
        options: TextDecodeOptions,
    ) ![]const u8 {
        // ...
    }
});
```

### Import Statements

**Update imports to use PascalCase filenames:**

```zig
❌ WRONG:
const TextDecoder = @import("text_decoder.zig").TextDecoder;
const TextDecoderOptions = @import("text_decoder_options.zig").TextDecoderOptions;

✅ CORRECT:
const TextDecoder = @import("TextDecoder.zig").TextDecoder;
const TextDecoderOptions = @import("TextDecoderOptions.zig").TextDecoderOptions;
```

### WebIDL Mixins

**Interface mixins define reusable member bundles that can be included in multiple interfaces using composition.**

#### What are Mixins?

From WebIDL spec:
> An interface mixin is a definition (matching `InterfaceMixin`) that declares a set of members that can be included by one or more interfaces.

Mixins are used to share common attributes and methods across multiple interfaces without inheritance.

#### Critical Rule: Always Use `webidl.mixin()`

**ALL mixin definitions MUST use `webidl.mixin()` wrapper:**

```zig
// IDL:
// interface mixin TextDecoderCommon {
//   readonly attribute DOMString encoding;
//   readonly attribute boolean fatal;
//   readonly attribute boolean ignoreBOM;
// };

// ✅ CORRECT: Use webidl.mixin()
pub const TextDecoderCommon = webidl.mixin(struct {
    encoding: []const u8,
    fatal: webidl.boolean,
    ignoreBOM: webidl.boolean,
});

// ❌ WRONG: Don't use plain struct or webidl.interface()
pub const TextDecoderCommon = struct { ... };  // ❌ Missing webidl.mixin()
pub const TextDecoderCommon = webidl.interface(struct { ... });  // ❌ Wrong wrapper
```

**Key differences from `webidl.interface()`:**
- Mixins **cannot be instantiated** directly
- Mixins **define shared members** that are included in other interfaces
- Mixins **do not have constructors**
- Mixins are **included** using the WebIDL `includes` statement
- **MUST be wrapped with `webidl.mixin()`**

#### Mixin Composition Pattern (REQUIRED)

**When an interface includes a mixin, use composition by embedding the mixin as a field:**

```zig
// IDL:
// interface TextDecoder {
//   constructor(...);
//   // ... TextDecoder-specific members
// };
// TextDecoder includes TextDecoderCommon;

// ✅ CORRECT: Embed mixin as a field
pub const TextDecoder = webidl.interface(struct {
    mixin: TextDecoderCommon,  // ✅ Embed mixin as field
    
    allocator: std.mem.Allocator,
    enc: *const Encoding,
    doNotFlush: bool,
    bomSeen: bool,
    // ... other interface-specific fields
    
    pub fn init(allocator: std.mem.Allocator, label: []const u8, options: TextDecoderOptions) !TextDecoder {
        const enc = try getEncoding(label);
        return .{
            .mixin = .{  // ✅ Initialize mixin
                .encoding = enc.name,
                .fatal = options.fatal,
                .ignoreBOM = options.ignoreBOM,
            },
            .allocator = allocator,
            .enc = enc,
            .doNotFlush = false,
            .bomSeen = false,
        };
    }
    
    // ✅ Delegate getters to mixin
    pub inline fn encoding(self: *const TextDecoder) []const u8 {
        return self.mixin.encoding;
    }
    
    pub inline fn getFatal(self: *const TextDecoder) webidl.boolean {
        return self.mixin.fatal;
    }
    
    pub inline fn getIgnoreBOM(self: *const TextDecoder) webidl.boolean {
        return self.mixin.ignoreBOM;
    }
});
```

**❌ WRONG: Direct field duplication (DO NOT DO THIS):**
```zig
// ❌ Don't duplicate mixin fields directly in the interface
pub const TextDecoder = webidl.interface(struct {
    // ❌ These should be in a mixin field, not duplicated
    encoding: []const u8,       
    fatal: webidl.boolean,      
    ignoreBOM: webidl.boolean,  
    
    allocator: std.mem.Allocator,
    // ...
});
```

#### Multiple Mixin Composition

**When an interface includes multiple mixins, use descriptive field names:**

```zig
// IDL:
// interface TextDecoderStream {
//   constructor(...);
// };
// TextDecoderStream includes TextDecoderCommon;
// TextDecoderStream includes GenericTransformStream;

pub const TextDecoderStream = webidl.interface(struct {
    decoderMixin: TextDecoderCommon,        // ✅ First mixin
    transformMixin: GenericTransformStream, // ✅ Second mixin
    
    allocator: std.mem.Allocator,
    // ... other fields
    
    pub fn init(...) !TextDecoderStream {
        return .{
            .decoderMixin = .{
                .encoding = enc.name,
                .fatal = options.fatal,
                .ignoreBOM = options.ignoreBOM,
            },
            .transformMixin = .{
                .transform = transform,
            },
            // ... other fields
        };
    }
    
    // Delegate to TextDecoderCommon mixin
    pub inline fn encoding(self: *const TextDecoderStream) []const u8 {
        return self.decoderMixin.encoding;
    }
    
    // Delegate to GenericTransformStream mixin
    pub inline fn readable(self: *const TextDecoderStream) *ReadableStream {
        return self.transformMixin.readable();
    }
});
```

#### File Naming for Mixins

Mixin files follow the same PascalCase naming as interfaces:

```
❌ WRONG: text_decoder_common.zig
✅ CORRECT: TextDecoderCommon.zig
```

#### Verifying Mixin Usage in Specs

**When implementing an interface, ALWAYS check the spec for `includes` statements:**

```
// In specs/encoding.md:
TextDecoder includes TextDecoderCommon;
TextDecoderStream includes TextDecoderCommon;
```

**Steps to implement:**
1. Find all `includes` statements for the interface in the spec
2. Verify mixin definitions exist and use `webidl.mixin()`
3. Embed each mixin as a field in the interface
4. Delegate all mixin methods/getters to the mixin fields
5. Never duplicate mixin fields directly in the interface

#### Common WebIDL Mixins (Verified)

From the WHATWG specs:
- **TextDecoderCommon** (`webidl/src/encoding/TextDecoderCommon.zig`): Shared by `TextDecoder` and `TextDecoderStream` ✅
- **TextEncoderCommon** (`webidl/src/encoding/TextEncoderCommon.zig`): Shared by `TextEncoder` and `TextEncoderStream` ✅
- **GenericTransformStream** (`webidl/src/streams/GenericTransformStream.zig`): Shared by transform stream classes ✅
- **ReadableStreamGenericReader** (`webidl/src/streams/ReadableStreamGenericReader.zig`): Shared by reader classes ✅
- **WindowOrWorkerGlobalScope**: Shared by `Window` and `WorkerGlobalScope`
- **Body**: Shared by `Request` and `Response` (Fetch API)

#### Complete Mixin Example

**Mixin Definition (`TextEncoderCommon.zig`):**
```zig
const webidl = @import("webidl");

pub const TextEncoderCommon = webidl.mixin(struct {  // ✅ MUST use webidl.mixin()
    /// The encoding name (always "utf-8")
    encoding: []const u8,
});
```

**Interface Including Mixin (`TextEncoder.zig`):**
```zig
const webidl = @import("webidl");
const TextEncoderCommon = @import("TextEncoderCommon.zig").TextEncoderCommon;

pub const TextEncoder = webidl.interface(struct {
    mixin: TextEncoderCommon,  // ✅ Embed mixin as field
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) TextEncoder {
        return .{
            .mixin = .{  // ✅ Initialize mixin
                .encoding = "utf-8",
            },
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *TextEncoder) void {
        _ = self;
    }
    
    // ✅ Delegate getter to mixin
    pub inline fn encoding(self: *const TextEncoder) []const u8 {
        return self.mixin.encoding;
    }
    
    pub fn encode(self: *TextEncoder, input: []const u8) ![]const u8 {
        // Implementation
    }
});
```

#### Key Principles for Mixin Implementation

**✅ DO:**
1. **Always use `webidl.mixin()`** for mixin definitions
2. **Embed mixins as fields** in interfaces that include them
3. **Use descriptive field names** for multiple mixins (`decoderMixin`, `transformMixin`)
4. **Delegate all getters** from interface to mixin fields
5. **Initialize mixin fields** in constructor
6. **Check spec for `includes` statements** to find all required mixins
7. **Never duplicate mixin fields** directly in the interface struct

**❌ DON'T:**
1. Don't use plain `struct` for mixins (must use `webidl.mixin()`)
2. Don't use `webidl.interface()` for mixins (wrong wrapper)
3. Don't duplicate mixin fields directly in interface
4. Don't skip delegation - always delegate to mixin
5. Don't use generic names like `mixin1`, `mixin2` for multiple mixins
6. Don't bypass mixin fields with direct access

### Checklist for WebIDL Interfaces and Mixins

When creating or modifying WebIDL interfaces or mixins:

**General Requirements:**
- [ ] **Identify the WebIDL type**:
  - [ ] Use `webidl.interface()` for IDL `interface` definitions
  - [ ] Use `webidl.namespace()` for IDL `namespace` definitions
  - [ ] Use `webidl.mixin()` for IDL `interface mixin` definitions (REQUIRED)
- [ ] **File named in PascalCase** (e.g., `TextDecoder.zig`, not `text_decoder.zig`)
- [ ] **All attributes use camelCase** (e.g., `encodingName`, not `encoding_name`)
- [ ] **All methods use camelCase without prefixes** (e.g., `decode()`, not `call_decode()`)
- [ ] **Use WebIDL type aliases** (e.g., `webidl.boolean`, not `bool` for attributes)
- [ ] **Use WebIDL string types appropriately** (e.g., `webidl.DOMString` for UTF-16)
- [ ] **Import statements use PascalCase filenames**
- [ ] **Tests updated to use camelCase method names**
- [ ] **Documentation uses correct naming**

**For Mixin Definitions:**
- [ ] **MUST use `webidl.mixin()` wrapper** (not plain struct or webidl.interface)
- [ ] **Define only shared attributes** (no constructors, no instance-specific fields)
- [ ] **Use camelCase for mixin fields**
- [ ] **Document which interfaces include this mixin**

**For Interfaces Including Mixins:**
- [ ] **Check spec for ALL `includes` statements** for this interface
- [ ] **Embed each mixin as a field** (e.g., `mixin: TextDecoderCommon`)
- [ ] **Use descriptive field names** for multiple mixins (e.g., `decoderMixin`, `transformMixin`)
- [ ] **Initialize mixin fields in constructor**
- [ ] **Add delegation methods** for all mixin getters (e.g., `pub inline fn encoding(self) { return self.mixin.encoding; }`)
- [ ] **Never duplicate mixin fields** directly in the interface struct
- [ ] **Update all internal references** to use `self.mixin.field` instead of `self.field`

---

# Quick Reference

## Workflow Summary

1. **Identify context** - Which spec am I implementing?
2. **Find algorithm** - `rg -n "algorithm name" specs/[spec].md`
3. **Load complete section** - Read entire algorithm with context
4. **Map types to Zig** - Use type mapping tables above
5. **Implement with numbered comments** - Match spec steps exactly
6. **Document with spec reference** - Include URL and algorithm
7. **Test** - Verify against spec behavior

## Common Searches

```bash
# URL
rg -n "basic URL parser" specs/url.md
rg -n "host parser" specs/url.md

# Encoding
rg -n "UTF-8 decode" specs/encoding.md
rg -n "encode" specs/encoding.md

# Streams
rg -n "read from a readable stream" specs/streams.md
rg -n "write to a writable stream" specs/streams.md

# Infra
rg -n "append to a list" specs/infra.md
rg -n "ASCII lowercase" specs/infra.md
```

## Type Mapping Quick Lookup

```
String              → []const u8
Byte sequence       → []const u8
List<T>             → std.ArrayList(T)
Ordered map         → Custom struct (Infra pattern)
Boolean             → bool
Integer             → i32, u32, usize (context-dependent)
Optional<T>         → ?T
Enum/State          → enum
Record/Struct       → struct
```

---

## Integration with Other Skills

This skill works with:
- **zig** - Provides Zig idioms for implementing algorithms
- **monorepo_navigation** - Finds cross-spec dependencies
- **dependency_mocking** - Creates mocks for unimplemented dependencies

---

**Remember**: Read complete spec sections, map types precisely, implement with numbered comments matching spec steps, and always reference the specification in documentation.
