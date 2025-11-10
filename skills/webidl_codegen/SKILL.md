# WebIDL Codegen Skill

## ⚠️ CRITICAL - READ THIS FIRST ⚠️

**BEFORE writing or modifying ANY code in `webidl/src/`, you MUST:**

1. **ALWAYS prefix property getters with `get_`** (with underscore)
2. **ALWAYS prefix property setters with `set_`** (with underscore)
3. **ALWAYS prefix spec instance/static methods with `call_`**
4. **NEVER prefix `init()`, `deinit()`, or internal helpers**

**Violation of these rules is UNACCEPTABLE and will break the codebase.**

## Overview

This skill documents the WebIDL code generation system ported from zoop. It defines critical naming conventions and codegen behavior that MUST be followed when working with WebIDL interface files.

## Architecture

The WebIDL codegen system transforms source files in `webidl/src/` into generated code in `webidl/generated/`:

**Source Files (`webidl/src/`):**
- Contain `webidl.interface(struct { ... })` wrappers
- Define class hierarchies with inheritance via `pub const extends`
- Specify properties and methods
- Use `webidl.mixin()` for multiple inheritance

**Generated Files (`webidl/generated/`):**
- Strip `webidl.interface()` wrapper → plain `struct`
- **Flatten parent class fields directly into child** (no `.super` field)
- **Copy inherited methods with type rewriting** (`*Parent` → `*Child`)
- **Detect overrides** and skip copying overridden methods
- Generate property getters/setters
- Resolve cross-file inheritance

## How Inheritance Works

### The Key Principle: Flattened Fields

Zoop/WebIDL uses **flattened field inheritance** - parent fields are copied directly into the child struct, NOT nested in a `.super` field.

```zig
// ❌ WRONG - Traditional OOP (other languages)
child.parent.grandparent.field

// ✅ CORRECT - WebIDL (flattened)
child.field  // Direct access!
```

### What Gets Generated

When you use `pub const extends = ParentInterface`, the codegen:

1. **Flattens parent fields** directly into child struct (parent fields first, then child fields)
2. **Copies parent methods** with type rewriting (`*Parent` → `*Child`)
3. **Detects overrides** - If child defines same method name, parent version is NOT copied
4. **Preserves method bodies** - Inherited methods are copied verbatim, just with type rewritten

### Inheritance Example

#### Source Code (`webidl/src/`)

```zig
pub const ReadableStreamGenericReader = webidl.mixin(struct {
    allocator: std.mem.Allocator,
    stream: ?*ReadableStream,
    closed_promise: *AsyncPromise(void),
    
    pub fn call_cancel(self: *ReadableStreamGenericReader, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        // Implementation
    }
});

pub const ReadableStreamDefaultReader = webidl.interface(struct {
    pub const extends = ReadableStreamGenericReader;  // Inherit from mixin
    
    read_requests: std.ArrayList(*AsyncPromise(common.ReadResult)),
    
    pub fn call_read(self: *ReadableStreamDefaultReader) !*AsyncPromise(common.ReadResult) {
        // Implementation
    }
});
```

#### Generated Code (`webidl/generated/`)

```zig
// ReadableStreamGenericReader - plain struct (mixin stripped)
pub const ReadableStreamGenericReader = struct {
    allocator: std.mem.Allocator,
    stream: ?*ReadableStream,
    closed_promise: *AsyncPromise(void),
    
    pub fn call_cancel(self: *ReadableStreamGenericReader, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        // Implementation (unchanged)
    }
};

// ReadableStreamDefaultReader - inherits from GenericReader
pub const ReadableStreamDefaultReader = struct {
    // ===== FLATTENED PARENT FIELDS (from ReadableStreamGenericReader) =====
    allocator: std.mem.Allocator,
    stream: ?*ReadableStream,
    closed_promise: *AsyncPromise(void),
    
    // ===== OWN FIELDS =====
    read_requests: std.ArrayList(*AsyncPromise(common.ReadResult)),
    
    // ===== OWN METHOD =====
    pub fn call_read(self: *ReadableStreamDefaultReader) !*AsyncPromise(common.ReadResult) {
        // Implementation (unchanged)
    }
    
    // ===== INHERITED METHOD (copied with type rewritten) =====
    pub fn call_cancel(self: *ReadableStreamDefaultReader, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        // Implementation copied from parent
        // Type changed: *ReadableStreamGenericReader → *ReadableStreamDefaultReader
    }
};
```

### Key Points About Inheritance

1. **Field Access**: Always direct - `reader.stream`, never `reader.super.stream`
2. **Method Copying**: Inherited methods are fully copied, not delegated
3. **Type Rewriting**: Method signatures change to use child type
4. **Override Detection**: If child defines `call_read()`, parent's `call_read()` is NOT copied
5. **Zero Runtime Overhead**: No vtables, no indirection, just plain structs
6. **Initialization**: Child's `init()` must initialize ALL fields (parent + own)

### Multi-Level Inheritance

Inheritance can be chained:

```zig
// Grandparent
pub const Entity = webidl.interface(struct {
    id: u64,
});

// Parent  
pub const Character = webidl.interface(struct {
    pub const extends = Entity;
    name: []const u8,
});

// Child
pub const Player = webidl.interface(struct {
    pub const extends = Character;
    username: []const u8,
});
```

Generated `Player` will have ALL fields flattened:
```zig
pub const Player = struct {
    id: u64,           // From Entity (flattened)
    name: []const u8,  // From Character (flattened)
    username: []const u8,
};
```

### Mixins - WebIDL Includes Pattern

Mixins provide code reuse through the WebIDL `includes` mechanism. Unlike `extends` (single inheritance), an interface can include **multiple mixins**.

#### Defining a Mixin

Mixins are defined with `webidl.mixin()`:

```zig
pub const TextDecoderCommon = webidl.mixin(struct {
    encoding: []const u8,
    fatal: webidl.boolean,
    ignoreBOM: webidl.boolean,
});

pub const GenericTransformStream = webidl.mixin(struct {
    transform: *TransformStream,
    
    pub fn get_readable(self: *const GenericTransformStream) *ReadableStream {
        return self.transform.readableStream;
    }
    
    pub fn get_writable(self: *const GenericTransformStream) *WritableStream {
        return self.transform.writableStream;
    }
});
```

#### Including Mixins in an Interface

Use `pub const includes` to declare which mixins to flatten into the interface:

```zig
// Single mixin
pub const TextDecoder = webidl.interface(struct {
    pub const includes = .{TextDecoderCommon};
    
    allocator: std.mem.Allocator,
    enc: *const Encoding,
    // ... other fields
});

// Multiple mixins
pub const TextDecoderStream = webidl.interface(struct {
    pub const includes = .{
        TextDecoderCommon,
        GenericTransformStream,
    };
    
    allocator: std.mem.Allocator,
    decoder: *Decoder,
    // ... other fields
});
```

#### Generated Code - Complete Flattening

The codegen **flattens all mixin members** directly into the interface:

**Source (`webidl/src/encoding/TextDecoderStream.zig`):**
```zig
pub const TextDecoderStream = webidl.interface(struct {
    pub const includes = .{
        TextDecoderCommon,
        GenericTransformStream,
    };
    
    allocator: std.mem.Allocator,
    decoder: *Decoder,
    enc: *const Encoding,
});
```

**Generated (`webidl/generated/encoding/TextDecoderStream.zig`):**
```zig
pub const TextDecoderStream = struct {
    // ========================================================================
    // Fields from TextDecoderCommon mixin
    // ========================================================================
    encoding: []const u8,
    fatal: webidl.boolean,
    ignoreBOM: webidl.boolean,

    // ========================================================================
    // Fields from GenericTransformStream mixin
    // ========================================================================
    transform: *TransformStream,

    // ========================================================================
    // TextDecoderStream fields
    // ========================================================================
    allocator: std.mem.Allocator,
    decoder: *Decoder,
    enc: *const Encoding,

    // ========================================================================
    // Methods from GenericTransformStream mixin
    // ========================================================================
    
    /// (Included from GenericTransformStream mixin)
    pub fn get_readable(self: *const TextDecoderStream) *ReadableStream {
        return self.transform.readableStream;
    }
    
    /// (Included from GenericTransformStream mixin)
    pub fn get_writable(self: *const TextDecoderStream) *WritableStream {
        return self.transform.writableStream;
    }
    
    // ========================================================================
    // TextDecoderStream methods
    // ========================================================================
    // ... interface's own methods
};
```

#### Key Features of Mixin Flattening

1. **Complete Member Copying**: All fields and methods from mixins are copied directly into the interface
2. **Type Substitution**: Mixin method signatures are rewritten to use the interface type instead of mixin type
   - `*const TextDecoderCommon` → `*const TextDecoder`
   - `*GenericTransformStream` → `*TextDecoderStream`
3. **Section Headers**: Generated code has clear section headers for organization
4. **Method Annotations**: `(Included from MixinName mixin)` annotations show mixin source
5. **Doc Comment Preservation**: All doc comments from mixin members are preserved
6. **No Manual Delegation**: The interface doesn't need to manually implement mixin methods
7. **Import Filtering**: Mixin imports are automatically removed from generated files

#### Conflict Detection

The codegen enforces strict conflict rules:

**Field Conflicts → ERROR:**
```zig
// ❌ ERROR: Two mixins define the same field
pub const Mixin1 = webidl.mixin(struct {
    allocator: std.mem.Allocator,
});

pub const Mixin2 = webidl.mixin(struct {
    allocator: std.mem.Allocator,  // Conflicts with Mixin1
});

pub const MyInterface = webidl.interface(struct {
    pub const includes = .{Mixin1, Mixin2};  // ERROR at codegen
});
```

**Method Conflicts Between Mixins → ERROR:**
```zig
// ❌ ERROR: Two mixins define the same method
pub const Mixin1 = webidl.mixin(struct {
    pub fn get_value(self: *const Mixin1) i32 { }
});

pub const Mixin2 = webidl.mixin(struct {
    pub fn get_value(self: *const Mixin2) i32 { }  // Conflicts with Mixin1
});

pub const MyInterface = webidl.interface(struct {
    pub const includes = .{Mixin1, Mixin2};  // ERROR at codegen
});
```

**Interface Overriding Mixin Methods → ALLOWED:**
```zig
// ✅ ALLOWED: Interface can override mixin methods
pub const MyMixin = webidl.mixin(struct {
    pub fn call_process(self: *MyMixin) void {
        // Default implementation
    }
});

pub const MyInterface = webidl.interface(struct {
    pub const includes = .{MyMixin};
    
    // Override the mixin's method
    pub fn call_process(self: *MyInterface) void {
        // Custom implementation - this wins
    }
});
```

#### Member Ordering in Generated Code

The codegen preserves a predictable order:

**Fields:**
1. Mixin1 fields (in declaration order)
2. Mixin2 fields (in declaration order)
3. ... (additional mixins in includes order)
4. Interface's own fields (in declaration order)

**Methods:**
1. Mixin1 methods (in declaration order)
2. Mixin2 methods (in declaration order)
3. ... (additional mixins in includes order)
4. Interface's own methods (in declaration order)

**Note:** Only `pub` members from mixins are included. Private mixin members are not flattened.

#### Real-World Example

From WHATWG Streams Standard:

```zig
// Mixin definitions
pub const ReadableStreamGenericReader = webidl.mixin(struct {
    allocator: std.mem.Allocator,
    closedPromise: *AsyncPromise(void),
    stream: ?*ReadableStream,
    eventLoop: eventLoop.EventLoop,
    
    pub fn get_closed(self: *const ReadableStreamGenericReader) webidl.Promise(void) {
        // Implementation
    }
    
    pub fn call_cancel(self: *ReadableStreamGenericReader, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        // Implementation
    }
});

// Interface including the mixin
pub const ReadableStreamBYOBReader = webidl.interface(struct {
    pub const includes = .{ReadableStreamGenericReader};
    
    readIntoRequests: std.ArrayList(*AsyncPromise(common.ReadResult)),
    
    pub fn call_read(self: *ReadableStreamBYOBReader, view: webidl.ArrayBufferView) !*AsyncPromise(common.ReadResult) {
        // BYOB-specific implementation
    }
});
```

After codegen, `ReadableStreamBYOBReader` has:
- All 4 fields from `ReadableStreamGenericReader`
- The `readIntoRequests` field from itself
- `get_closed()` method (with type rewritten to use `*ReadableStreamBYOBReader`)
- `call_cancel()` method (with type rewritten)
- `call_read()` method from itself

#### Mixin Initialization Pattern

When including mixins, you must initialize mixin fields directly in `init()`:

```zig
// ❌ WRONG - Don't do this anymore (old pattern)
pub fn init(...) !MyInterface {
    return .{
        .mixin = .{  // NO! Mixin is not a field
            .field1 = value1,
        },
        .ownField = value2,
    };
}

// ✅ CORRECT - Initialize mixin fields directly
pub fn init(...) !MyInterface {
    return .{
        .field1 = value1,      // From mixin
        .field2 = value2,      // From mixin
        .ownField = value3,    // Own field
    };
}
```

#### When to Use Mixins vs. Extends

**Use `extends` for:**
- True parent-child "is-a" relationships
- Single inheritance hierarchies
- Core type hierarchies (Node → Element → HTMLElement)

**Use `includes` for:**
- Shared behavior across unrelated interfaces
- Readonly attributes that appear in multiple places
- Multiple behavior composition
- WebIDL interface mixins as defined in specs

**Example from WHATWG specs:**
- `ReadableStreamDefaultReader` and `ReadableStreamBYOBReader` both include `ReadableStreamGenericReader`
- `TextDecoder` and `TextDecoderStream` both include `TextDecoderCommon`
- `TextEncoderStream` includes both `TextEncoderCommon` and `GenericTransformStream`

## Critical Naming Conventions

### ⚠️ MANDATORY RULES - NEVER VIOLATE THESE

#### 1. Property Getters/Setters

**Getters MUST use `get_` prefix with underscore:**
```zig
// ✅ CORRECT
pub inline fn get_fatal(self: *const TextDecoder) webidl.boolean {
    return self.fatal;
}

pub inline fn get_ignoreBOM(self: *const TextDecoder) webidl.boolean {
    return self.ignoreBOM;
}

// ❌ WRONG - Missing underscore
pub inline fn getFatal(self: *const TextDecoder) webidl.boolean {
    return self.fatal;
}
```

**Setters MUST use `set_` prefix with underscore:**
```zig
// ✅ CORRECT
pub inline fn set_encoding(self: *TextDecoder, value: []const u8) void {
    self.encoding = value;
}

// ❌ WRONG - Missing underscore
pub inline fn setEncoding(self: *TextDecoder, value: []const u8) void {
    self.encoding = value;
}
```

#### 2. Spec Instance/Static Methods

**Spec-defined public methods MUST use `call_` prefix:**

```zig
// ✅ CORRECT - Spec methods with call_ prefix
pub fn call_decode(
    self: *TextDecoder,
    input: ?[]const u8,
    options: ?DecodeOptions,
) ![]const u8 {
    // ...
}

pub fn call_encode(self: *TextEncoder, input: []const u8) ![]u8 {
    // ...
}

pub fn call_locked(self: *const ReadableStream) bool {
    return self.reader != .none;
}

pub fn call_cancel(self: *ReadableStream, reason: ?webidl.JSValue) !*AsyncPromise(void) {
    // ...
}

// ❌ WRONG - Spec methods without call_ prefix
pub fn decode(...) { }
pub fn encode(...) { }
pub fn locked(...) { }
```

**How to identify spec methods:**
- Look for `Spec: § X.Y.Z` in doc comments (public API sections like § 4.1.x, § 4.2.x)
- Methods defined in WebIDL interface definitions
- Public methods that are part of the standard API

#### 3. Internal/Helper Methods

**Internal methods DO NOT get prefixes:**

```zig
// ✅ CORRECT - No prefix for internal methods
pub fn init(allocator: std.mem.Allocator) !TextDecoder {
    // ...
}

pub fn deinit(self: *TextDecoder) void {
    // ...
}

pub fn getNumReadRequests(self: *const ReadableStream) usize {
    // Internal helper - no call_ prefix
}

pub fn fulfillReadRequest(self: *ReadableStream, chunk: common.JSValue, done: bool) void {
    // Internal algorithm - no call_ prefix
}

pub fn closeInternal(self: *ReadableStream) void {
    // Internal helper - no call_ prefix
}

// ❌ WRONG - Internal methods should not have call_ prefix
pub fn call_init(...) { }
pub fn call_getNumReadRequests(...) { }
```

**How to identify internal methods:**
- `init`, `deinit` - Constructor/destructor
- Methods with `Internal` suffix
- Methods starting with `get/has/fulfill` that are helpers (not properties)
- Methods in spec sections like § 4.7+ (internal abstract operations)
- Methods not exposed in WebIDL interface definition

## Summary Table - MEMORIZE THIS

| Method Type | Prefix | Example | ALWAYS/NEVER |
|-------------|--------|---------|--------------|
| Property Getter | `get_` | `get_fatal()`, `get_ignoreBOM()`, `get_encoding()`, `get_readable()` | **ALWAYS use get_ with underscore** |
| Property Setter | `set_` | `set_encoding()`, `set_fatal()` | **ALWAYS use set_ with underscore** |
| Spec Instance Method | `call_` | `call_decode()`, `call_encode()`, `call_locked()`, `call_cancel()`, `call_getReader()`, `call_pipeTo()`, `call_assert()`, `call_log()` | **ALWAYS use call_ prefix** |
| Spec Static Method | `call_` | `call_from()`, `call_of()` | **ALWAYS use call_ prefix** |
| Constructor | **None** | `init()` | **NEVER use prefix** |
| Destructor | **None** | `deinit()` | **NEVER use prefix** |
| Internal Helper | **None** | `getNumReadRequests()`, `fulfillReadRequest()`, `closeInternal()` | **NEVER use call_ prefix** |

## Complete Examples from Real Code

### Property Getters - MUST have get_ prefix

```zig
// Encoding attributes
pub inline fn get_encoding(self: *const TextDecoder) []const u8
pub inline fn get_fatal(self: *const TextDecoder) webidl.boolean
pub inline fn get_ignoreBOM(self: *const TextDecoder) webidl.boolean

// Stream attributes  
pub fn get_readable(self: *const TransformStream) *ReadableStream
pub fn get_writable(self: *const TransformStream) *WritableStream

// BYOB attributes
pub fn get_view(self: *const ReadableStreamBYOBRequest) ?webidl.JSValue
```

### Spec Methods - MUST have call_ prefix

```zig
// Encoding methods
pub fn call_decode(self: *TextDecoder, input: ?[]const u8, options: ?DecodeOptions) ![]const u8
pub fn call_encode(self: *TextEncoder, input: []const u8) ![]u8
pub fn call_encodeInto(self: *TextEncoder, source: []const u8, dest: []u8) EncodeIntoResult

// Stream methods
pub fn call_locked(self: *const ReadableStream) bool
pub fn call_cancel(self: *ReadableStream, reason: ?webidl.JSValue) !*AsyncPromise(void)
pub fn call_getReader(self: *ReadableStream, options: ?ReaderOptions) !ReaderUnion
pub fn call_pipeTo(self: *ReadableStream, dest: *WritableStream, options: ?PipeOptions) !*AsyncPromise(void)
pub fn call_pipeThrough(self: *ReadableStream, transform: TransformPair, options: ?PipeOptions) *ReadableStream
pub fn call_tee(self: *ReadableStream) !TeeResult
pub fn call_from(allocator: std.mem.Allocator, loop: EventLoop, asyncIterable: webidl.JSValue) !*ReadableStream
pub fn call_values(self: *ReadableStream, preventCancel: bool) !ReadableStreamAsyncIterator
pub fn call_asyncIterator(self: *ReadableStream) !ReadableStreamAsyncIterator

// Controller methods
pub fn call_enqueue(self: *ReadableStreamDefaultController, chunk: ?webidl.JSValue) !void
pub fn call_close(self: *ReadableStreamDefaultController) !void
pub fn call_error(self: *ReadableStreamDefaultController, e: ?webidl.JSValue) void
pub fn call_desiredSize(self: *const ReadableStreamDefaultController) ?f64

// Reader methods
pub fn call_read(self: *ReadableStreamDefaultReader) !*AsyncPromise(ReadResult)
pub fn call_releaseLock(self: *ReadableStreamDefaultReader) void

// Writer methods
pub fn call_getWriter(self: *WritableStream) !*WritableStreamDefaultWriter
pub fn call_write(self: *WritableStreamDefaultWriter, chunk: ?webidl.JSValue) !*AsyncPromise(void)
pub fn call_close(self: *WritableStreamDefaultWriter) !*AsyncPromise(void)
pub fn call_abort(self: *WritableStreamDefaultWriter, reason: ?webidl.JSValue) !*AsyncPromise(void)
pub fn call_releaseLock(self: *WritableStreamDefaultWriter) void
pub fn call_desiredSize(self: *const WritableStreamDefaultWriter) ?f64

// Console methods (ALL console methods need call_ prefix)
pub fn call_assert(self: *Console, condition: bool, data: []const webidl.JSValue) void
pub fn call_clear(self: *Console) void
pub fn call_debug(self: *Console, data: []const webidl.JSValue) void
pub fn call_error(self: *Console, data: []const webidl.JSValue) void
pub fn call_info(self: *Console, data: []const webidl.JSValue) void
pub fn call_log(self: *Console, data: []const webidl.JSValue) void
pub fn call_table(self: *Console, tabular_data: ?webidl.JSValue, properties: ?[]const webidl.DOMString) void
pub fn call_trace(self: *Console, data: []const webidl.JSValue) void
pub fn call_warn(self: *Console, data: []const webidl.JSValue) void
pub fn call_dir(self: *Console, item: ?webidl.JSValue, options: ?webidl.JSValue) void
pub fn call_dirxml(self: *Console, data: []const webidl.JSValue) void
pub fn call_count(self: *Console, label: []const u8) void
pub fn call_countReset(self: *Console, label: []const u8) void
pub fn call_group(self: *Console, data: []const webidl.JSValue) void
pub fn call_groupCollapsed(self: *Console, data: []const webidl.JSValue) void
pub fn call_groupEnd(self: *Console) void
pub fn call_time(self: *Console, label: []const u8) void
pub fn call_timeLog(self: *Console, label: []const u8, data: []const webidl.JSValue) void
pub fn call_timeEnd(self: *Console, label: []const u8) void

// BYOB methods
pub fn call_respond(self: *ReadableStreamBYOBRequest, bytesWritten: u64) !void
pub fn call_respondWithNewView(self: *ReadableStreamBYOBRequest, view: ?webidl.JSValue) !void
pub fn call_getBYOBRequest(self: *ReadableByteStreamController) !?*ReadableStreamBYOBRequest

// Transform methods
pub fn call_enqueue(self: *TransformStreamDefaultController, chunk: ?webidl.JSValue) !void
pub fn call_terminate(self: *TransformStreamDefaultController) void

// Queuing strategy
pub fn call_size(_: *const CountQueuingStrategy, _: ?webidl.JSValue) f64
```

### Internal Methods - NO prefix

```zig
// Constructors/destructors - NO prefix
pub fn init(allocator: std.mem.Allocator) !TextDecoder
pub fn deinit(self: *TextDecoder) void

// Internal helpers - NO prefix
pub fn getNumReadRequests(self: *const ReadableStream) usize
pub fn hasDefaultReader(self: *const ReadableStream) bool
pub fn hasBYOBReader(self: *const ReadableStream) bool
pub fn getNumReadIntoRequests(self: *const ReadableStream) usize
pub fn fulfillReadRequest(self: *ReadableStream, chunk: common.JSValue, done: bool) void
pub fn fulfillReadIntoRequest(self: *ReadableStream, chunk: webidl.ArrayBufferView, done: bool) void
pub fn closeInternal(self: *ReadableStream) void
pub fn errorInternal(self: *ReadableStream, e: common.JSValue) void
pub fn calculateDesiredSize(self: *const ReadableStreamDefaultController) ?f64
pub fn releaseSteps(self: *ReadableStreamDefaultController) void
pub fn pullInto(self: *ReadableByteStreamController, view: webidl.ArrayBufferView) !*AsyncPromise(ReadResult)
pub fn callPullIfNeeded(self: *ReadableByteStreamController) void
pub fn handleQueueDrain(self: *ReadableByteStreamController) void
pub fn processReadRequestsUsingQueue(self: *ReadableByteStreamController) !void
```

## Verification Checklist

Before committing changes to `webidl/src/` files:

- [ ] All property getters use `get_` (with underscore)
- [ ] All property setters use `set_` (with underscore)
- [ ] All spec public methods use `call_` prefix
- [ ] `init()` and `deinit()` have NO prefix
- [ ] Internal helpers have NO prefix
- [ ] Run `zig build codegen` to regenerate files
- [ ] Check generated files have correct naming

## Common Mistakes to Avoid

### ❌ Mistake 1: Missing Underscore in Getters/Setters
```zig
// WRONG
pub inline fn getFatal(self: *const TextDecoder) webidl.boolean { }
pub inline fn setEncoding(self: *TextDecoder, value: []const u8) void { }

// CORRECT
pub inline fn get_fatal(self: *const TextDecoder) webidl.boolean { }
pub inline fn set_encoding(self: *TextDecoder, value: []const u8) void { }
```

### ❌ Mistake 2: Missing call_ Prefix on Spec Methods
```zig
// WRONG - Spec method without prefix
pub fn decode(self: *TextDecoder, input: ?[]const u8) ![]const u8 { }
pub fn locked(self: *const ReadableStream) bool { }

// CORRECT
pub fn call_decode(self: *TextDecoder, input: ?[]const u8) ![]const u8 { }
pub fn call_locked(self: *const ReadableStream) bool { }
```

### ❌ Mistake 3: Adding call_ to Internal Methods
```zig
// WRONG - Internal methods should not have call_
pub fn call_init(allocator: std.mem.Allocator) !TextDecoder { }
pub fn call_getNumReadRequests(self: *const ReadableStream) usize { }

// CORRECT
pub fn init(allocator: std.mem.Allocator) !TextDecoder { }
pub fn getNumReadRequests(self: *const ReadableStream) usize { }
```

## Codegen Configuration

The codegen is configured in `build.zig`:

```zig
const webidl_codegen = b.addRunArtifact(webidl_codegen_exe);
webidl_codegen.addArgs(&.{
    "--source-dir", "webidl/src",
    "--output-dir", "webidl/generated",
    "--getter-prefix", "get_",     // ← Must have underscore
    "--setter-prefix", "set_",     // ← Must have underscore
});
```

**NEVER change these prefixes** - they are part of the WebIDL standard.

## Porting from Zoop

This codegen was ported from zoop with the following transformations:

| Zoop | WebIDL |
|------|--------|
| `zoop.class()` | `webidl.interface()` |
| `zoop.mixin()` | `webidl.mixin()` |
| `zoop.namespace()` | `webidl.namespace()` |
| Class | Interface |

The core codegen engine (`src/webidl/codegen/codegen.zig`) is 3740 lines ported directly from zoop.

## Files

- `src/webidl/codegen/codegen.zig` - Core generation engine (3740 lines)
- `src/webidl/codegen/codegen_main.zig` - CLI entry point
- `src/webidl/codegen/root.zig` - Module exports
- `webidl/src/` - Source files with webidl.interface() wrappers
- `webidl/generated/` - Generated plain structs (auto-generated, DO NOT EDIT)

## Running Codegen

```bash
# Generate all webidl interfaces
zig build codegen

# Codegen runs automatically during build
zig build
```

## References

- Original zoop implementation: `/Users/bcardarella/projects/zig-whatwg/zoop/`
- WebIDL spec: https://webidl.spec.whatwg.org/
- Zoop README: Understanding inheritance flattening and method copying

---

## Enforcement Rules

### When Writing NEW Code in webidl/src/

**EVERY TIME you write a method in a webidl.interface() file, you MUST ask:**

1. **Is this a property getter (IDL attribute)?** → Use `get_` prefix
2. **Is this a property setter (writable attribute)?** → Use `set_` prefix  
3. **Is this a spec-defined public method?** → Use `call_` prefix
4. **Is this init(), deinit(), or internal helper?** → NO prefix

**DO NOT skip this check. DO NOT assume. DO NOT forget.**

### When Reviewing Existing Code

If you see ANY of these patterns, they are **WRONG** and must be fixed:

- `pub inline fn encoding(` → Should be `pub inline fn get_encoding(`
- `pub inline fn readable(` → Should be `pub fn get_readable(`
- `pub fn decode(` → Should be `pub fn call_decode(`
- `pub fn locked(` → Should be `pub fn call_locked(`
- `pub fn assert(` → Should be `pub fn call_assert(`
- `pub fn log(` → Should be `pub fn call_log(`

### Verification Command

After modifying ANY file in `webidl/src/`, run:

```bash
# Check for methods missing get_ prefix (property getters)
grep -rn "pub inline fn [a-z][a-zA-Z]*(" webidl/src --include="*.zig" | \
  grep -v "get_\|set_\|init\|deinit"

# Check for methods missing call_ prefix (spec methods)  
grep -rn "pub fn [a-z][a-zA-Z]*(" webidl/src --include="*.zig" | \
  grep -v "get_\|set_\|init\|deinit\|call_\|Internal\|fulfill\|close\|error\|has\|is\|calculate\|release\|handle\|process"

# Regenerate
zig build codegen
```

If the grep commands find ANYTHING, those methods need to be fixed.

---

## ⚠️ FINAL WARNING ⚠️

**These naming conventions are MANDATORY and NON-NEGOTIABLE.**

Violating them:
- Breaks the WebIDL code generation system
- Breaks WHATWG spec compliance  
- Breaks the JavaScript bindings layer
- Makes the codebase inconsistent
- Will require comprehensive fixes across all files

**ALWAYS follow these rules. NO EXCEPTIONS.**

## WebIDL Extended Attributes

### Overview

WebIDL extended attributes (defined in the [WebIDL spec](https://webidl.spec.whatwg.org/#idl-extended-attributes)) control how interfaces are exposed in JavaScript environments. Our codegen system parses these attributes from source files and emits them as metadata in generated files.

### How to Define Extended Attributes

Extended attributes are specified in the **options parameter** (second argument) to `webidl.interface()`, `webidl.namespace()`, and `webidl.mixin()`:

```zig
pub const MyInterface = webidl.interface(struct {
    // fields and methods
}, .{
    // Extended attributes here
    .exposed = &.{.all},
    .transferable = true,
});
```

### Complete Attribute Reference

All available attributes from `InterfaceOptions`:

| Attribute | Type | Purpose | Example |
|-----------|------|---------|---------|
| `.exposed` | `[]const ExposureScope` | **REQUIRED** - Which scopes this is available in | `.exposed = &.{.all}` |
| `.transferable` | `bool` | Can be transferred via `postMessage()` | `.transferable = true` |
| `.serializable` | `bool` | Can be serialized via `structuredClone()` | `.serializable = true` |
| `.secure_context` | `bool` | Only available in HTTPS contexts | `.secure_context = true` |
| `.cross_origin_isolated` | `bool` | Only available when cross-origin isolated | `.cross_origin_isolated = true` |
| `.global` | `?[]const []const u8` | Interface is a global object | `.global = &.{"Window"}` |
| `.legacy_factory_function` | `?[]const u8` | Legacy constructor | `.legacy_factory_function = "Image(unsigned long w, unsigned long h)"` |
| `.legacy_no_interface_object` | `bool` | No interface object created | `.legacy_no_interface_object = true` |
| `.legacy_window_alias` | `?[]const []const u8` | Alias on Window | `.legacy_window_alias = &.{"WebKitCSSMatrix"}` |
| `.legacy_namespace` | `?[]const u8` | Place in namespace | `.legacy_namespace = "WebAssembly"` |
| `.legacy_override_builtins` | `bool` | For legacy platform objects | `.legacy_override_builtins = true` |

### Exposure Scopes

The `.exposed` attribute accepts an array of `ExposureScope` enum values:

```zig
pub const ExposureScope = enum {
    all,              // [Exposed=*] - All scopes
    Window,           // [Exposed=Window] - Browser window only
    Worker,           // [Exposed=Worker] - All workers
    DedicatedWorker,  // [Exposed=DedicatedWorker] - Dedicated workers only
    SharedWorker,     // [Exposed=SharedWorker] - Shared workers only
    ServiceWorker,    // [Exposed=ServiceWorker] - Service workers only
};
```

### Common Patterns

#### 1. Interface Exposed Everywhere (Most Common)

Used for APIs available in all contexts (Window, Workers, etc.):

```zig
// Streams interfaces - available everywhere
pub const ReadableStream = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
    .transferable = true,  // Also transferable
});

// Encoding interfaces - available everywhere
pub const TextEncoder = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
});
```

#### 2. Interface Exposed Only in Window

Used for DOM APIs that only make sense in browser windows:

```zig
pub const Node = webidl.interface(struct {
    pub const extends = EventTarget;
    
    node_type: u16,
    node_name: []const u8,
    // ... other fields
}, .{
    .exposed = &.{.Window},  // Only in browser window
});

pub const Element = webidl.interface(struct {
    pub const extends = Node;
    
    tag_name: []const u8,
    // ... other fields
}, .{
    .exposed = &.{.Window},
});
```

#### 3. Namespace Exposed Everywhere

Used for utility namespaces like console:

```zig
pub const console = webidl.namespace(struct {
    countMap: infra.OrderedMap(webidl.DOMString, u32),
    timerTable: infra.OrderedMap(webidl.DOMString, infra.Moment),
    
    pub fn call_log(self: *console, data: []const webidl.JSValue) void {
        // ... implementation
    }
    
    // ... other methods
}, .{
    .exposed = &.{.all},
});
```

#### 4. Multiple Exposure Scopes

For APIs available in multiple but not all contexts:

```zig
pub const MyAPI = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.Window, .Worker},  // Window and Workers, but not ServiceWorker
});
```

#### 5. Transferable Streams

The three stream interfaces that can be transferred between contexts:

```zig
pub const ReadableStream = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
    .transferable = true,  // Can be sent via postMessage()
});

pub const WritableStream = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
    .transferable = true,
});

pub const TransformStream = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
    .transferable = true,
});
```

### Real-World Examples

#### Example 1: ReadableStream (Interface, All Scopes, Transferable)

From `webidl/src/streams/ReadableStream.zig`:

```zig
pub const ReadableStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    controller: Controller,
    reader: Reader,
    state: StreamState,
    storedError: ?common.JSValue,
    eventLoop: eventLoop.EventLoop,
    
    pub fn call_getReader(self: *ReadableStream, options: ?ReaderOptions) !ReaderUnion {
        // ... implementation
    }
    
    pub fn call_locked(self: *const ReadableStream) bool {
        return self.reader != .none;
    }
    
    // ... more methods
}, .{
    .exposed = &.{.all},
    .transferable = true,
});
```

#### Example 2: Node (Interface, Window Only)

From `webidl/src/dom/Node.zig`:

```zig
pub const Node = webidl.interface(struct {
    pub const extends = EventTarget;
    
    node_type: u16,
    node_name: []const u8,
    node_value: ?[]const u8,
    owner_document: ?*Document,
    parent_node: ?*Node,
    children: std.ArrayList(*Node),
    
    pub fn get_nodeType(self: *const Node) u16 {
        return self.node_type;
    }
    
    pub fn get_nodeName(self: *const Node) []const u8 {
        return self.node_name;
    }
    
    // ... more methods
}, .{
    .exposed = &.{.Window},
});
```

#### Example 3: console (Namespace, All Scopes)

From `webidl/src/console/console.zig`:

```zig
pub const console = webidl.namespace(struct {
    countMap: infra.OrderedMap(webidl.DOMString, u32),
    timerTable: infra.OrderedMap(webidl.DOMString, infra.Moment),
    groupStack: std.ArrayList([]const u8),
    
    pub fn call_log(self: *console, data: []const webidl.JSValue) void {
        // ... implementation
    }
    
    pub fn call_error(self: *console, data: []const webidl.JSValue) void {
        // ... implementation
    }
    
    // ... 16 more console methods
}, .{
    .exposed = &.{.all},
});
```

### Generated Metadata

The codegen parses these options and emits `__webidl__` metadata in generated files:

**Source (`webidl/src/streams/ReadableStream.zig`):**
```zig
pub const ReadableStream = webidl.interface(struct {
    // ... implementation
}, .{
    .exposed = &.{.all},
    .transferable = true,
});
```

**Generated (`webidl/generated/streams/ReadableStream.zig`):**
```zig
pub const ReadableStream = struct {
    // ... flattened implementation
    
    // WebIDL extended attributes metadata
    pub const __webidl__ = .{
        .name = "ReadableStream",
        .kind = .interface,
        .exposed = &.{.all},
        .transferable = true,
        .serializable = false,
        .secure_context = false,
        .cross_origin_isolated = false,
    };
};
```

### Runtime Usage of Metadata

The `__webidl__` metadata enables runtime discovery and binding:

```zig
// Check if type has WebIDL metadata
if (@hasDecl(ReadableStream, "__webidl__")) {
    const meta = ReadableStream.__webidl__;
    
    // Check exposure scope
    if (shouldBindInScope(meta.exposed, .Window)) {
        try bindInterface(runtime, ReadableStream, meta);
    }
    
    // Check if transferable
    if (meta.transferable) {
        try registerTransferable(runtime, ReadableStream);
    }
}
```

### Attribute Requirements by Spec

#### WHATWG Streams Standard
All stream interfaces: `.exposed = &.{.all}`

Transferable interfaces:
- `ReadableStream` - `.transferable = true`
- `WritableStream` - `.transferable = true`
- `TransformStream` - `.transferable = true`

#### WHATWG Encoding Standard
All encoding interfaces: `.exposed = &.{.all}`

#### WHATWG URL Standard
All URL interfaces: `.exposed = &.{.all}`

#### WHATWG Console Standard
The console namespace: `.exposed = &.{.all}`

#### WHATWG DOM Standard
EventTarget group: `.exposed = &.{.all}`
- `EventTarget`, `Event`, `CustomEvent`, `AbortController`, `AbortSignal`

Node group: `.exposed = &.{.Window}`
- `Node`, `Document`, `Element`, `Attr`, `CharacterData`, `Text`, `Comment`, etc.

### Rules and Best Practices

#### Rule 1: Always Specify .exposed

Every interface, namespace, and mixin **MUST** have an `.exposed` attribute:

```zig
// ✅ CORRECT
pub const MyInterface = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},  // REQUIRED
});

// ❌ WRONG - Missing .exposed
pub const MyInterface = webidl.interface(struct {
    // ...
}, .{
    .transferable = true,  // ERROR: .exposed is required
});
```

#### Rule 2: Match WHATWG Spec Attributes

Always check the WebIDL definition in the WHATWG spec for correct attributes:

```webidl
// From WHATWG Streams spec:
[Exposed=*, Transferable]
interface ReadableStream { ... }
```

Translates to:
```zig
pub const ReadableStream = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},      // [Exposed=*]
    .transferable = true,     // [Transferable]
});
```

#### Rule 3: Use .all for Universal APIs

Most WHATWG APIs are designed to work everywhere:

```zig
// Encoding, Streams, URL, Console - all use .all
.exposed = &.{.all}
```

#### Rule 4: Use .Window for DOM APIs

DOM nodes and elements only make sense in browser windows:

```zig
// Node, Element, Document, etc. - use .Window
.exposed = &.{.Window}
```

#### Rule 5: Transferable Implies Structured Clone Semantics

Only use `.transferable = true` for objects that:
- Can be transferred between contexts (window ↔ worker)
- Follow structured clone semantics
- Are explicitly marked `[Transferable]` in WHATWG specs

Currently only 3 interfaces:
- `ReadableStream`
- `WritableStream`  
- `TransformStream`

### Verification Checklist

Before committing changes:

- [ ] Every interface/namespace has `.exposed` attribute
- [ ] Exposure scope matches WHATWG spec WebIDL definition
- [ ] Transferable only on ReadableStream, WritableStream, TransformStream
- [ ] Run `zig build codegen` to verify parsing succeeds
- [ ] Check generated file has correct `__webidl__` metadata
- [ ] Full build succeeds: `zig build`

### Common Mistakes

#### ❌ Mistake 1: Forgetting .exposed

```zig
// WRONG
pub const MyInterface = webidl.interface(struct {
    // ...
}, .{
    .transferable = true,  // Missing .exposed!
});

// CORRECT
pub const MyInterface = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},
    .transferable = true,
});
```

#### ❌ Mistake 2: Wrong Exposure Scope

```zig
// WRONG - Node should be Window-only
pub const Node = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},  // ERROR: Node is Window-only per spec
});

// CORRECT
pub const Node = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.Window},
});
```

#### ❌ Mistake 3: Incorrect Transferable

```zig
// WRONG - TextEncoder is not transferable
pub const TextEncoder = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},
    .transferable = true,  // ERROR: Not in spec
});

// CORRECT
pub const TextEncoder = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},
});
```

### Finding Extended Attributes in Specs

When implementing a new interface, check the WebIDL definition in the WHATWG spec:

**Example from Streams spec:**
```webidl
[Exposed=*, Transferable]
interface ReadableStream {
  constructor(optional object underlyingSource, optional QueuingStrategy strategy = {});
  // ... methods
};
```

Maps to:
```zig
pub const ReadableStream = webidl.interface(struct {
    // ...
}, .{
    .exposed = &.{.all},      // [Exposed=*]
    .transferable = true,     // [Transferable]
});
```

**Example from DOM spec:**
```webidl
[Exposed=Window]
interface Node : EventTarget {
  // ... properties and methods
};
```

Maps to:
```zig
pub const Node = webidl.interface(struct {
    pub const extends = EventTarget;
    // ...
}, .{
    .exposed = &.{.Window},   // [Exposed=Window]
});
```
