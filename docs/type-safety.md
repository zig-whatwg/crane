# Type Safety Guidelines: Legitimate `anyopaque` Usage

This document identifies patterns where `anyopaque` is **intentionally used** and should NOT be refactored.

## Overview

The codebase is undergoing a refactoring effort to replace `anyopaque` with typed alternatives where possible. However, certain uses of `anyopaque` are legitimate and necessary for:

1. **FFI Extern Functions** - C interop requires opaque pointers
2. **Instance.state Field** - Runtime polymorphism for WebIDL interfaces
3. **VTable-based Backends** - Type erasure for pluggable implementations

This document serves as the authoritative reference for contributors to understand which `anyopaque` patterns to KEEP vs REFACTOR.

---

## 1. FFI Extern Functions (KEEP)

**Location**: `src/runtime/engines/v8/ffi.zig` (and other engine FFI files)

### Why KEEP

V8, JSC, and QuickJS are C++ libraries accessed via C ABI. The C API uses opaque void pointers that Zig represents as `anyopaque`. These cannot be typed more specifically because:

- The actual struct layout is managed by the external library
- We only have pointers, never the actual definitions
- Type safety is maintained via distinct `opaque {}` types for each V8 type

### Pattern

```zig
// src/runtime/engines/v8/ffi.zig

// KEEP: V8 types are opaque by design - we only have pointers
pub const Isolate = opaque {};
pub const Context = opaque {};
pub const Value = opaque {};
pub const Object = opaque {};
pub const Function = opaque {};

// KEEP: FFI function signatures require anyopaque for C interop
pub extern fn v8_Isolate_SetData(isolate: *Isolate, slot: c_int, data: ?*anyopaque) void;
pub extern fn v8_Isolate_GetData(isolate: *Isolate, slot: c_int) ?*anyopaque;

// KEEP: Callback signatures must match C function pointer expectations
pub const FunctionCallback = *const fn (*const FunctionCallbackInfo) callconv(.c) void;
pub extern fn v8_FunctionCallbackInfo_SetReturnValueLocal(
    self: *const FunctionCallbackInfo,
    local_ptr: ?*anyopaque,  // KEEP: V8 Local<Value> internal pointer
) void;

// KEEP: Module resolution callbacks use anyopaque for user data
pub const ModuleResolveCallback = *const fn (
    user_data: ?*anyopaque,  // KEEP: User-provided context
    specifier: [*]const u8,
    specifier_len: c_int,
    referrer_module: ?*anyopaque,  // KEEP: Opaque module reference
) callconv(.c) ?*anyopaque;

// KEEP: Weak callback signatures
pub const WeakCallbackFn = *const fn (
    data: ?*anyopaque,  // KEEP: User data for weak reference
    length_in_bytes: usize,
) callconv(.c) void;
```

### Count

~53 occurrences in `ffi.zig` - ALL should be kept

### Inline Comment Convention

Add `// KEEP: FFI boundary - C interop requires anyopaque` to these uses.

---

## 2. Instance.state Field (KEEP)

**Location**: `src/runtime/instance.zig`

### Why KEEP

The `Instance` struct is a **type-erased handle** that enables polymorphism across all WebIDL interfaces. Different interfaces (Element, Document, Event, etc.) have different state types, but they all use the same 24-byte `Instance` handle.

This is the **foundation** of the WebIDL runtime - changing this would require a fundamental architecture redesign.

### Pattern

```zig
// src/runtime/instance.zig

/// Type-erased instance handle (24 bytes)
///
/// Every WebIDL interface instance is represented by this uniform handle:
/// - vtable: Points to the interface's method dispatch table
/// - state: Points to the interface's type-specific state (FullState)
/// - ctx: Runtime context (pointer to JS execution environment)
///
/// This enables polymorphism - a NodeList can hold mixed Node/Element/Text
/// instances and dispatch methods correctly through their vtables.
pub const Instance = struct {
    vtable: *const VTable,
    state: *anyopaque,  // KEEP: Polymorphic state - type known at interface level
    ctx: Context,

    /// Get the state as a typed pointer (unsafe - caller must ensure correct type)
    pub inline fn getState(self: *const Instance, comptime T: type) *T {
        return @ptrCast(@alignCast(self.state));
    }
};
```

### Why This Can't Be Typed

1. **Runtime Polymorphism**: A `NodeList` holds `Instance` pointers to Elements, Documents, and Text nodes. The actual state type varies per instance.

2. **VTable Dispatch**: Method calls go through the vtable, which knows the correct state type. The vtable's `deinit` function knows how to clean up the specific state.

3. **Binary Size**: Using generics (`Instance(T)`) would cause code bloat - each interface would have its own Instance type, duplicating the allocation/deallocation logic.

### Type Safety Mechanism

Type safety is provided through the `getState(T)` method and VTable dispatch:

```zig
// At interface implementation level - caller knows the type
const element_state = instance.getState(ElementState);
element_state.tag_name = "div";
```

### Count

1-2 occurrences (the state field and methods_ptr in VTable)

### Inline Comment Convention

```zig
state: *anyopaque,  // KEEP: Polymorphic state - use getState(T) for type safety
```

---

## 3. VTable-based Backends (KEEP)

**Location**: `src/platform/*.zig` (layout_backend.zig, clipboard_backend.zig, etc.)

### Why KEEP

Platform backends use the VTable pattern for **pluggable implementations**. The `ptr: *anyopaque` field enables:

1. **Runtime Backend Switching**: Swap between real and stub implementations
2. **Testing**: Use mock backends without changing code
3. **Cross-Platform**: Different backends for different platforms

This is a **valid polymorphism pattern** that cannot be typed without losing flexibility.

### Pattern

```zig
// src/platform/layout_backend.zig

/// Abstract layout backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real layout engines, stub/mock backends) to be swapped at runtime.
pub const LayoutBackend = struct {
    /// Implementation pointer.
    ptr: *anyopaque,  // KEEP: VTable polymorphism - different impl types

    /// Virtual function table.
    vtable: *const VTable,

    pub const VTable = struct {
        // KEEP: VTable functions take anyopaque as first param
        // because they're called with different impl types
        getOffsetWidth: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,
        getOffsetHeight: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,
        // ...
        deinit: *const fn (ptr: *anyopaque) void,
    };
};

// Implementation casts ptr back to concrete type:
fn deinitImpl(ptr: *anyopaque) void {
    const self: *StubLayoutBackend = @ptrCast(@alignCast(ptr));
    self.allocator.destroy(self);
}
```

### Pattern in src/platform/vtables.zig

```zig
// src/platform/vtables.zig

/// All VTable function pointers use user_context: OpaquePtr as first parameter
/// This enables different backend implementations to store their own state
pub const OpaquePtr = ?*anyopaque;

// KEEP: All VTable callback signatures use OpaquePtr for impl-specific state
pub const ClipboardVTable = extern struct {
    call_readText: *const fn (
        user_context: OpaquePtr,  // KEEP: Backend-specific context
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,
    // ...
};
```

### Count

~200+ occurrences in src/platform/ - mostly VTable function signatures

### Inline Comment Convention

```zig
ptr: *anyopaque,  // KEEP: VTable polymorphism - enables runtime backend switching
```

For VTable function parameters:
```zig
getOffsetWidth: *const fn (ptr: *anyopaque, ...) f64,  // KEEP: VTable dispatch
```

---

## Summary: What to KEEP vs REFACTOR

### KEEP (Do NOT Refactor)

| Pattern | Location | Reason |
|---------|----------|--------|
| FFI extern function signatures | `src/runtime/engines/*/ffi.zig` | C interop requires opaque pointers |
| Callback function pointer types | `src/runtime/engines/*/ffi.zig` | Must match C ABI |
| `Instance.state` field | `src/runtime/instance.zig` | Runtime polymorphism |
| `VTable.methods_ptr` field | `src/runtime/instance.zig` | Type-erased method table |
| VTable `ptr` field | `src/platform/*_backend.zig` | Pluggable implementations |
| VTable function parameters | `src/platform/vtables.zig` | Backend polymorphism |
| Opaque handle types | `src/dom/handles.zig` | Breaking circular imports (see docs/patterns/opaque-handles.md) |

### REFACTOR (Convert to Typed Alternatives)

| Pattern | Replacement | Location |
|---------|-------------|----------|
| `engine_ctx: *anyopaque` | `*runtime.EngineContext` | Runtime files |
| `controller_v8: *anyopaque` | `*runtime.Instance` | Streams files |
| `promise_resolver: *anyopaque` | `runtime.JSValue` | Various |
| `user_data: *anyopaque` (in callbacks) | `TypedCallback(T)` variants | Various |
| `context: *anyopaque` | `*runtime.Context` | Various |
| WebIDL `any` type parameters | `runtime.JSValue` | Various |
| Interface pointers | `*runtime.Instance` | Various |

---

## Contributor Guidelines

### Before Refactoring `anyopaque`

1. **Check this document** - Is the pattern listed as KEEP?
2. **Check for `// KEEP:` comments** - Inline comments indicate intentional usage
3. **Ask if unsure** - When in doubt, create an issue to discuss

### When You Find Legitimate `anyopaque`

Add an inline comment explaining why:

```zig
// For FFI:
data: ?*anyopaque,  // KEEP: FFI boundary - C interop requires anyopaque

// For polymorphism:
state: *anyopaque,  // KEEP: Polymorphic state - use getState(T) for type safety

// For VTables:
ptr: *anyopaque,  // KEEP: VTable polymorphism - enables runtime backend switching
```

### When You Find `anyopaque` That Should Be Typed

Replace with the appropriate typed alternative:

```zig
// Before:
underlyingSink: *anyopaque,

// After:
underlyingSink: runtime.JSValue,  // WebIDL 'any' type
```

---

## Related Documentation

- [Opaque Handle Pattern](patterns/opaque-handles.md) - For breaking circular imports
- [WebIDL Type Mapping](../specs/whatwg/webidl.md) - How WebIDL types map to Zig
- [Runtime Infrastructure](../src/runtime/README.md) - Runtime type system overview

---

## Metrics

**Target**: Reduce `anyopaque` from ~2,897 occurrences to <200 (legitimate uses only)

**Legitimate Uses (estimated)**:
- FFI boundaries: ~100
- Instance.state: ~5
- VTable patterns: ~100

**Expected Refactoring Coverage**: >93%
