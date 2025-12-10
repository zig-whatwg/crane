# Opaque Handle Pattern

A type-safe pattern for breaking circular imports and creating clear module boundaries in Zig.

## Problem

Circular imports between modules that reference each other's types. This is common in DOM implementations where:

- Element references Document (owner document)
- Attr references Element (owner element)  
- ShadowRoot references Element (host)
- RegisteredObserver references MutationObserver

Without a solution, importing these types creates circular dependencies that Zig's compiler will reject.

## Solution

Use `opaque {}` types as handles that can be passed between modules without creating import cycles. The opaque type acts as a type-safe placeholder that can be cast to the concrete type when needed.

```zig
// handles.zig - Central definition of opaque handles
pub const ElementHandle = opaque {};
pub const DocumentHandle = opaque {};
pub const NodeHandle = opaque {};

// attr.zig - Uses handles instead of importing Element
const handles = @import("handles.zig");

pub const Attr = struct {
    // Instead of: owner_element: ?*Element,  // Would create circular import!
    owner_element: ?*handles.ElementHandle,  // Type-safe, no import cycle
};
```

## Real-World Example: DOM Handles

The `src/dom/handles.zig` file provides the canonical example of this pattern:

```zig
// src/dom/handles.zig
pub const ElementHandle = opaque {};
pub const DocumentHandle = opaque {};
pub const ShadowRootHandle = opaque {};
pub const SlotHandle = opaque {};
pub const MutationObserverHandle = opaque {};
pub const CustomElementRegistryHandle = opaque {};
pub const NodeHandle = opaque {};
```

Usage in `registered_observer.zig`:

```zig
const handles = @import("handles.zig");

pub const RegisteredObserver = struct {
    /// The observer object (typed handle to avoid circular import with MutationObserver)
    observer: *handles.MutationObserverHandle,
    options: Options,
    
    // ...
};
```

Usage in `attr_with_base.zig`:

```zig
const handles = @import("handles.zig");

pub const AttrWithBase = struct {
    base: NodeBase,
    local_name: []const u8,
    value: []const u8,
    // ...
    
    /// The element this attribute belongs to (weak reference, typed handle)
    owner_element: ?*handles.ElementHandle,
};
```

## Conversion Functions

Provide conversion functions to safely cast between handles and concrete types or `*anyopaque`:

```zig
// Convert ElementHandle to anyopaque (for legacy interop)
pub fn elementToAnyopaque(handle: ?*ElementHandle) ?*anyopaque {
    if (handle) |h| {
        return @ptrCast(h);
    }
    return null;
}

// Convert anyopaque to ElementHandle
pub fn anyopaqueToElement(ptr: ?*anyopaque) ?*ElementHandle {
    if (ptr) |p| {
        return @ptrCast(@alignCast(p));
    }
    return null;
}
```

## Debug Assertions

Always add validation in debug and release-safe builds to catch invalid handles early:

```zig
const std = @import("std");
const builtin = @import("builtin");

/// Validate that a handle pointer is valid (non-null and aligned).
/// Only performs checks in debug/release-safe builds.
fn validateHandlePtr(ptr: ?*const anyopaque, comptime type_name: []const u8) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (ptr) |p| {
            const addr = @intFromPtr(p);
            // Check alignment (minimum 4-byte for pointers)
            if (addr & (@alignOf(*anyopaque) - 1) != 0) {
                std.debug.panic("{s} handle has invalid alignment: 0x{x}", .{ type_name, addr });
            }
        }
    }
}

/// Validate an ElementHandle pointer in debug builds.
pub fn validateElementHandle(handle: ?*const ElementHandle) void {
    validateHandlePtr(@ptrCast(handle), "Element");
}

/// Convert with validation in one call
pub fn elementToAnyopaqueChecked(handle: ?*ElementHandle) ?*anyopaque {
    validateElementHandle(handle);
    return elementToAnyopaque(handle);
}
```

Add assertion functions for cases where null is unexpected:

```zig
/// Assert that a handle is not null.
/// Panics in debug/release-safe builds if null.
fn assertNotNull(ptr: ?*const anyopaque, comptime type_name: []const u8) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (ptr == null) {
            std.debug.panic("{s} handle is null when non-null was expected", .{type_name});
        }
    }
}

/// Assert that an ElementHandle is not null. Panics in debug builds if null.
pub fn assertElementNotNull(handle: ?*const ElementHandle) void {
    assertNotNull(@ptrCast(handle), "Element");
}
```

## Other Uses in This Codebase

### FFI Boundaries (V8, JSC, QuickJS)

Opaque types are extensively used for FFI bindings where we only have pointers to external types:

```zig
// src/runtime/engines/v8/ffi.zig
pub const Isolate = opaque {};     // V8 Isolate
pub const Context = opaque {};     // V8 Context
pub const Value = opaque {};       // V8 Value
pub const Object = opaque {};      // V8 Object
pub const Function = opaque {};    // V8 Function
```

This is appropriate because:
- We only interact with these types through C API function pointers
- The actual struct layout is managed by V8
- Type safety is maintained via distinct opaque types

### Database Backends

External database libraries also use opaque handles:

```zig
// src/storage/backends/sqlite.zig
pub const sqlite3 = opaque {};
pub const sqlite3_stmt = opaque {};

// src/storage/backends/leveldb.zig
pub const leveldb_t = opaque {};
pub const leveldb_options_t = opaque {};
pub const leveldb_iterator_t = opaque {};
```

## When to Use

✅ **Breaking circular imports** - Primary use case. When Module A needs to reference Module B's types and vice versa.

✅ **Type-safe boundaries between subsystems** - When you want to enforce that code goes through proper APIs rather than accessing internals.

✅ **FFI boundaries with external libraries** - When wrapping C/C++ libraries where you only have opaque pointers.

✅ **Hiding implementation details** - When a module should expose only a handle, not its internal structure.

## When NOT to Use

❌ **When types can be imported directly without cycles** - If there's no circular dependency, just import the type directly for better ergonomics.

❌ **When runtime type information is needed** - Opaque types cannot be introspected. If you need to check the actual type at runtime, use a different pattern (tagged unions, vtables, etc.).

❌ **For generic container types** - Use Zig's generics instead: `ArrayList(T)` rather than opaque handles.

❌ **When you need to access fields directly** - Opaque types hide all structure. If callers need field access, the type shouldn't be opaque.

## Pattern Checklist

When implementing this pattern:

- [ ] Define all related handles in a central `handles.zig` file
- [ ] Provide conversion functions for each handle type
- [ ] Add `validate*Handle()` functions with debug assertions
- [ ] Add `assert*NotNull()` functions where null is unexpected
- [ ] Add comprehensive tests for round-trip conversions
- [ ] Document the circular dependency being broken

## Testing

Always test handle conversions:

```zig
test "handles: round-trip conversion" {
    var dummy: u8 = 42;
    const ptr: *anyopaque = &dummy;

    // Test Element round-trip
    const element_handle = anyopaqueToElement(ptr);
    try std.testing.expect(element_handle != null);
    const back = elementToAnyopaque(element_handle);
    try std.testing.expectEqual(ptr, back.?);
}

test "handles: null handling" {
    const result = anyopaqueToElement(null);
    try std.testing.expectEqual(@as(?*ElementHandle, null), result);

    const back = elementToAnyopaque(null);
    try std.testing.expectEqual(@as(?*anyopaque, null), back);
}

test "handles: validation passes for valid handles" {
    var dummy: u64 align(8) = 42;
    const ptr: *anyopaque = @ptrCast(&dummy);

    const element_handle = anyopaqueToElement(ptr);
    
    // Validation should pass (not panic) for valid handle
    validateElementHandle(element_handle);
}
```

## Related Patterns

- **Tagged Pointer Pattern** (`src/runtime/tagged_pointer.zig`) - For type-safe wrapping of V8 pointers with type tags
- **VTable Pattern** (`src/streams/internal/algorithm.zig`) - For polymorphic behavior with explicit dispatch
- **Registry Pattern** (`src/webidl/codegen/registry.zig`) - For managing type mappings across modules

## References

- DOM Handles Implementation: `src/dom/handles.zig`
- V8 FFI Handles: `src/runtime/engines/v8/ffi.zig`
- Zig Language Reference: [Opaque Types](https://ziglang.org/documentation/master/#opaque)
