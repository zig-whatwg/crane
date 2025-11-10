# WebIDL Codegen Skill

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

## Summary Table

| Method Type | Prefix | Example |
|-------------|--------|---------|
| Property Getter | `get_` | `get_fatal()`, `get_ignoreBOM()` |
| Property Setter | `set_` | `set_encoding()`, `set_fatal()` |
| Spec Instance Method | `call_` | `call_decode()`, `call_encode()`, `call_locked()` |
| Spec Static Method | `call_` | `call_from()`, `call_of()` |
| Constructor | None | `init()` |
| Destructor | None | `deinit()` |
| Internal Helper | None | `getNumReadRequests()`, `fulfillReadRequest()` |

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

**REMEMBER: These naming conventions are MANDATORY. Violating them breaks the WebIDL code generation system and the WHATWG spec compliance.**
