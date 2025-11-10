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
- Define class hierarchies with inheritance
- Specify properties and methods

**Generated Files (`webidl/generated/`):**
- Strip `webidl.interface()` wrapper → plain `struct`
- Flatten parent class fields directly into child
- Copy inherited methods with type rewriting
- Generate property getters/setters
- Resolve cross-file inheritance

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
