# Legitimate anyopaque Uses

This document catalogs all legitimate `anyopaque` uses in the WHATWG codebase that are required
for FFI, C ABI compatibility, or established Zig patterns (like VTables). These uses should
**NOT** be refactored and are marked with `// KEEP: anyopaque required - [reason]` comments.

## Categories of Legitimate Use

### 1. C ABI / FFI Boundaries

When interfacing with C libraries or exposing C-compatible APIs, `anyopaque` is required because:
- C's `void*` maps to Zig's `*anyopaque`
- Function pointers with `callconv(.c)` require C-compatible types
- User context/data pointers in callbacks must be type-erased

### 2. VTable Pattern for Polymorphism

The VTable pattern (like `std.mem.Allocator`) uses `anyopaque` for:
- Type-erased context pointers (`ptr: *anyopaque`)
- Virtual function table callbacks
- Enables different implementations to share a common interface

### 3. JS Engine Handles

JavaScript engine integration requires `anyopaque` for:
- V8 handles (Local, Global, Persistent) are opaque from Zig's perspective
- Engine-agnostic interfaces must use type erasure
- Promise handles, object references, etc.

### 4. WebIDL Spec Types

Some WebIDL types are inherently opaque:
- `object` - any JS object reference
- `symbol` - unique JS symbol identifiers

---

## File-by-File Catalog

### V8 Engine Integration

#### `src/runtime/engines/v8/binding.zig`
Engine-agnostic binding interface requiring type erasure at FFI boundary.

```zig
// Lines 106-112: EngineBinding trait interface uses anyopaque
fn v8RegisterInterface(
    engine_ctx: *anyopaque,  // KEEP: EngineBinding trait - engine-agnostic
    ...
)
```

All functions in the EngineBinding vtable use `*anyopaque` for:
- `engine_ctx` - Engine context (V8 Context, JSC GlobalObject, etc.)
- `zig_instance` - Zig-side instance pointers
- `js_value` - JS engine value handles

#### `src/runtime/js_value.zig`
JSValue abstraction layer for engine-agnostic JS value handling.

```zig
// Lines 98, 167, 208, etc.: Engine handle storage
ptr: *anyopaque  // KEEP: V8 Local<Value>*, Global<Value>*, etc.

// Lines 226, 291: Legacy compatibility APIs
pub fn fromInstanceAnyopaque(inst: *anyopaque) JSValue
pub fn fromAnyopaque(ptr: ?*const anyopaque) JSValue
```

### Platform Capabilities (C ABI Exports)

#### `src/platform/exports.zig`
C-compatible exports for Swift, Kotlin, and other language bindings.

```zig
// Line 125: User context for platform backend
pub export fn whatwg_platform_create_with_context(user_context: ?*anyopaque) callconv(.c) ?*PlatformBackend

// Lines 188-199: User context getter/setter
pub export fn whatwg_platform_get_user_context(backend: ?*const PlatformBackend) callconv(.c) ?*anyopaque
pub export fn whatwg_platform_set_user_context(backend: ?*PlatformBackend, user_context: ?*anyopaque) callconv(.c) void
```

#### `src/platform/vtables.zig`
VTable definitions for platform capabilities using C calling convention.

```zig
// Line 37: Common opaque pointer type
pub const OpaquePtr = ?*anyopaque;

// Lines 41-44: C-compatible allocator interface
pub const AllocFn = *const fn (size: usize, user_data: OpaquePtr) callconv(.c) ?[*]u8;
pub const FreeFn = *const fn (ptr: [*]u8, size: usize, user_data: OpaquePtr) callconv(.c) void;
```

#### Backend VTables (Common Pattern)
Each platform backend uses the same VTable pattern:

- `src/platform/timer_backend.zig`
- `src/platform/clipboard_backend.zig`
- `src/platform/notification_backend.zig`
- `src/platform/push_backend.zig`

```zig
// Common pattern in all backends:
const Backend = struct {
    ptr: *anyopaque,  // KEEP: VTable pattern - type-erased implementation pointer
    vtable: *const VTable,
};

const VTable = struct {
    operation: *const fn (ptr: *anyopaque, ...) ReturnType,  // KEEP: VTable dispatch
    deinit: *const fn (ptr: *anyopaque) void,                // KEEP: VTable cleanup
};
```

### Streams Standard Implementation

#### `src/streams/internal/event_loop.zig`
Event loop abstraction using VTable pattern.

```zig
// Lines 62-66: Microtask type
pub const Microtask = struct {
    callback: *const fn (context: ?*anyopaque) void,  // KEEP: VTable callback
    context: ?*anyopaque,                              // KEEP: VTable context
};

// Lines 99-115: EventLoop interface
pub const EventLoop = struct {
    ptr: *anyopaque,  // KEEP: VTable pattern - opaque impl pointer
    vtable: *const struct {
        queueMicrotask: *const fn (ptr: *anyopaque, task: Microtask) void,
        // ... other vtable functions
    },
};
```

#### `src/streams/internal/read_request.zig` & `src/streams/internal/read_into_request.zig`
WHATWG Streams spec read request callbacks using VTable pattern.

```zig
// Lines 149-159: ReadRequest VTable
pub const ReadRequest = struct {
    context: *anyopaque,  // KEEP: VTable context
    vtable: *const struct {
        chunk_steps: *const fn (*anyopaque, Value) void,   // KEEP: VTable callback
        close_steps: *const fn (*anyopaque) void,          // KEEP: VTable callback
        error_steps: *const fn (*anyopaque, Value) void,   // KEEP: VTable callback
    },
};
```

#### `src/streams/internal/common.zig`
Common algorithm types using VTable pattern for type erasure.

```zig
// Algorithm callback types - all use VTable pattern
pub const Algorithm = struct {
    context: *anyopaque,  // KEEP: VTable context
    vtable: *const struct {
        call: *const fn (*anyopaque) anyerror!common.JSValue,
        deinit: *const fn (*anyopaque) void,
    },
};
```

#### `src/streams/internal/v8_promise_chaining.zig`
V8 promise chaining with C FFI callbacks.

```zig
// Lines 55-56: C FFI callback signatures
pub const FulfillCallback = *const fn (ctx: ?*anyopaque, value: ?*anyopaque) callconv(.c) void;
pub const RejectCallback = *const fn (ctx: ?*anyopaque, reason: ?*anyopaque) callconv(.c) void;
```

#### `src/streams/internal/v8_resources.zig`
V8 handle resource management.

```zig
// Lines 34-38: V8 handle disposal
const Handle = struct {
    handle: *anyopaque,                             // KEEP: V8 Global<T>*
    dispose_fn: *const fn (*anyopaque) void,       // KEEP: Type-erased disposal
};
```

#### `src/streams/internal/async_promise.zig`
Async promise handling with type-erased callbacks.

```zig
// Lines 148-177: Promise callback signatures
on_fulfilled_ctx: ?*const fn (*anyopaque, T) anyerror!T,
on_rejected_ctx: ?*const fn (*anyopaque, webidl.errors.Exception) anyerror!T,
context: ?*anyopaque,  // KEEP: VTable context
```

### HTML Event Loop

#### `src/html/event_loop/microtask.zig`
Microtask checkpoint callbacks using VTable pattern.

```zig
// Lines 95-114: MicrotaskCheckpointCallbacks
pub const MicrotaskCheckpointCallbacks = struct {
    notify_rejected_promises: ?*const fn (context: ?*anyopaque) void,
    cleanup_indexeddb: ?*const fn (context: ?*anyopaque) void,
    clear_kept_objects: ?*const fn (context: ?*anyopaque) void,
    record_timing_info: ?*const fn (context: ?*anyopaque) void,
    context: ?*anyopaque,  // KEEP: VTable context - allows any environment type
};
```

### WebIDL Type System

#### `src/webidl/types/primitives.zig`
WebIDL primitive types that are inherently opaque.

```zig
// Lines 483-492: Opaque WebIDL types
/// WebIDL 'object' type - any JavaScript object reference
/// KEEP: anyopaque required - Per WebIDL spec, 'object' represents any JS object
pub const object_type = *anyopaque;

/// WebIDL 'symbol' type - JavaScript symbol value  
/// KEEP: anyopaque required - Symbols are opaque primitive values in JavaScript
pub const symbol_type = *anyopaque;
```

### JS Bindings Registry

#### `src/js_bindings/types.zig`
Binding descriptor types for heterogeneous registry pattern.

```zig
// All descriptor types use anyopaque for function pointers because:
// 1. Comptime reflection extracts metadata from arbitrary interfaces
// 2. Function signatures vary per interface/method
// 3. Type is restored at JS engine binding layer

pub const ConstructorDescriptor = struct {
    impl: *const anyopaque,  // KEEP: Heterogeneous registry pattern
};

pub const MethodDescriptor = struct {
    impl: *const anyopaque,  // KEEP: Heterogeneous registry pattern
};

pub const AttributeDescriptor = struct {
    getter: *const anyopaque,  // KEEP: Heterogeneous registry pattern
    setter: ?*const anyopaque, // KEEP: Heterogeneous registry pattern
};

pub const ConstantDescriptor = struct {
    value: *const anyopaque,  // KEEP: Constants can be any primitive type
};

pub const ParameterDescriptor = struct {
    default_value: ?*const anyopaque,  // KEEP: Default values match parameter type
};
```

### Service Worker

#### `src/service_worker/service_worker.zig`
Service worker registration and global object references.

```zig
// Lines 39-43: Registration and global references
containing_registration: ?*anyopaque = null,  // KEEP: Cross-realm reference
global_object: ?*anyopaque = null,            // KEEP: JS engine global object handle
```

---

## Adding KEEP Comments

When you encounter a legitimate `anyopaque` use, add a comment in this format:

```zig
/// KEEP: anyopaque required - [specific reason]
/// [Optional: additional context about why this cannot be typed]
field_name: *anyopaque,
```

Common reasons include:
- `C ABI boundary` - Required for `callconv(.c)` FFI
- `VTable pattern` - Like std.mem.Allocator, enables polymorphism
- `V8/JS engine handle` - Engine provides opaque handles
- `Engine-agnostic interface` - EngineBinding trait requires type erasure
- `Heterogeneous registry` - Binding registry holds multiple interface types
- `WebIDL spec type` - Some WebIDL types are inherently opaque (object, symbol)

---

## Summary Statistics

| Category | File Count | `anyopaque` Uses |
|----------|------------|------------------|
| V8 Engine Integration | 3 | ~50 |
| Platform VTables | 5 | ~80 |
| Streams VTables | 8 | ~60 |
| HTML Event Loop | 1 | ~10 |
| WebIDL Types | 2 | ~8 |
| JS Bindings | 1 | ~6 |
| **Total** | **~20** | **~214** |

All uses are documented with KEEP comments in the source code.

---

## What NOT to Document Here

Do NOT add uses that should be refactored:
- Generic `*anyopaque` that could use comptime generics
- Unnecessary type erasure in internal APIs
- Legacy code that hasn't been updated

If you're unsure whether a use is legitimate, check:
1. Does it cross a C ABI boundary?
2. Does it implement VTable pattern for polymorphism?
3. Does it interface with JS engine handles?
4. Is it a WebIDL spec type that's inherently opaque?

If none of these apply, the use may be refactorable.
