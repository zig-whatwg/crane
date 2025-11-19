# ECMAScript Built-in Types (Used in WebIDL)

This directory contains Zig implementations of ECMAScript built-in types that are **explicitly used as type annotations** in WebIDL files.

## Methodology

These types were identified by searching all IDL files in `/Users/bcardarella/projects/webref/ed/idl/` for ECMAScript type usage in:
- Attribute types
- Operation parameter types
- Operation return types
- Dictionary member types

## Architecture

These types form the **JavaScript runtime layer** that WebIDL interfaces with:

```
┌─────────────────────────────────────────┐
│  WebIDL Typedefs (src/webidl/typedefs/) │
│  BufferSource, ArrayBufferView, etc.    │
└───────────────┬─────────────────────────┘
                │ references
┌───────────────▼─────────────────────────┐
│  Runtime Types (src/runtime/typedefs/)  │ ◄── THIS MODULE
│  ArrayBuffer, Promise, TypedArrays, etc.│
└───────────────┬─────────────────────────┘
                │ uses
┌───────────────▼─────────────────────────┐
│  WHATWG Infra (src/infra/)              │
│  String, List, Map, primitives          │
└─────────────────────────────────────────┘
```

## Types Included

### 1. Promise Type (595 occurrences in IDL files)
**File:** `Promise.zig`

The Promise type is heavily used across all modern Web APIs for asynchronous operations.

**Examples in IDL:**
```webidl
Promise<Response> fetch(RequestInfo input);
Promise<undefined> setSinkId(DOMString sinkId);
Promise<sequence<DOMString>> getTags();
```

**Implementation Status:** 🚧 Stub (state machine only)

---

### 2. ArrayBuffer (95 occurrences)
**File:** `ArrayBuffer.zig`

Raw binary data buffer used for file I/O, encryption, media processing.

**Examples in IDL:**
```webidl
readonly attribute ArrayBuffer message;
Promise<ArrayBuffer> arrayBuffer();
ArrayBuffer getMappedRange(GPUSize64 offset);
```

**Implementation Status:** ✅ Full (alloc, detach, byteLength)

---

### 3. SharedArrayBuffer
**File:** `SharedArrayBuffer.zig`

Shared memory buffer for concurrent access with atomic operations. Used with `[AllowShared]` extended attribute.

**Examples in IDL:**
```webidl
// Used when [AllowShared] appears on buffer source types
```

**Implementation Status:** ✅ Full (alloc with alignment, deinit)

---

### 4. Typed Array Types (87 occurrences total)

| File | Type | Element | Size | Occurrences |
|------|------|---------|------|-------------|
| `Uint8Array.zig` | Uint8Array | u8 | 1 byte | Most common |
| `Float32Array.zig` | Float32Array | f32 | 4 bytes | Common in graphics APIs |
| `Int32Array.zig` | Int32Array | i32 | 4 bytes | Common |
| `Int8Array.zig` | Int8Array | i8 | 1 byte | Less common |
| `Int16Array.zig` | Int16Array | i16 | 2 bytes | Less common |
| `Uint16Array.zig` | Uint16Array | u16 | 2 bytes | Less common |
| `Uint32Array.zig` | Uint32Array | u32 | 4 bytes | Less common |
| `Uint8ClampedArray.zig` | Uint8ClampedArray | u8 (clamped) | 1 byte | Less common |
| `Float64Array.zig` | Float64Array | f64 | 8 bytes | Less common |
| `BigInt64Array.zig` | BigInt64Array | i64 | 8 bytes | Rare |
| `BigUint64Array.zig` | BigUint64Array | u64 | 8 bytes | Rare |
| `TypedArray.zig` | TypedArray(T) | Generic | - | Helper |

**Examples in IDL:**
```webidl
Uint8Array encode(USVString input);
readonly attribute Float32Array? position;
typedef Uint8Array BigInteger;
```

**Implementation Status:** ✅ Full (get, set, asSlice, asConstSlice)

---

### 5. DataView (17 occurrences)
**File:** `DataView.zig`

Low-level view providing methods to read/write multiple number types with explicit endianness control.

**Examples in IDL:**
```webidl
// DataView is part of buffer source types
// Used with [AllowShared] extended attribute
```

**Implementation Status:** ✅ Core (getUint8, setUint8, getInt32, setInt32)

---

### 6. Object (generic ECMAScript object)
**File:** `Object.zig`

The IDL `object` type represents any ECMAScript object value.

**Examples in IDL:**
```webidl
attribute object? valueAsDate;
readonly attribute object data;
undefined dir(optional any item, optional object? options);
```

**Implementation Status:** 🚧 Stub (requires JS runtime integration)

---

## Types NOT Included

The following ECMAScript types were **not found in IDL type annotations**:

❌ **Error types** (EvalError, RangeError, ReferenceError, TypeError, URIError)
- Not used as IDL types
- Errors are handled via WebIDL exceptions (DOMException)

❌ **Array<T>**
- WebIDL uses `sequence<T>` instead
- JavaScript Arrays map to WebIDL sequences

❌ **Map<K,V>, Set<T>**
- WebIDL uses `maplike<K,V>` and `setlike<T>` instead
- Not used as standalone type annotations

❌ **WeakMap, WeakSet**
- Not found in any IDL files

❌ **Date, RegExp, Symbol, Function**
- Not used as IDL type annotations
- May be used internally in algorithms, but not as interface types

---

## Usage Example

```zig
const runtime_types = @import("runtime/typedefs");
const std = @import("std");

pub fn example() !void {
    const allocator = std.heap.page_allocator;
    
    // Create an ArrayBuffer
    var buffer = try runtime_types.ArrayBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);
    
    // Create a Uint8Array view
    var uint8_view = try runtime_types.Uint8Array.init(&buffer, 0, 256);
    try uint8_view.set(0, 42);
    const value = try uint8_view.get(0); // 42
    
    // Use zero-copy slice access
    const slice = try uint8_view.asSlice();
    @memset(slice, 0);
    
    // Create a Promise
    var promise = runtime_types.Promise(u32).init();
    promise.resolve(123);
}
```

---

## File Summary

**19 files total:**
- 1 generic: `TypedArray.zig`
- 11 typed arrays: Int8/16/32, Uint8/16/32/ClampedArray, BigInt64/Uint64, Float32/64
- 3 buffer types: ArrayBuffer, SharedArrayBuffer, DataView
- 1 promise: Promise
- 1 object: Object
- 2 docs: README.md, root.zig

---

## Implementation Status

### ✅ Fully Implemented (Core Functionality)
- ArrayBuffer (alloc, detach, isDetached, byteLength)
- SharedArrayBuffer (alloc with atomic alignment, deinit, byteLength)
- TypedArray generic (get, set, asSlice, asConstSlice)
- All 11 specific typed arrays
- BigInt64Array, BigUint64Array (get/set i64/u64)
- DataView (core getters/setters)

### 🚧 Stub Implementation (Requires JS Runtime)
- Promise<T> (state machine stub - needs async/await integration)
- Object (requires property storage and [[Prototype]] chain)

---

## WebIDL Specification References

- **ECMAScript Specification**: https://tc39.es/ecma262/
  - § 25.1 ArrayBuffer Objects
  - § 25.2 SharedArrayBuffer Objects
  - § 25.3 DataView Objects
  - § 22.2 TypedArray Objects
  - § 27.2 Promise Objects

- **WebIDL Specification**: https://webidl.spec.whatwg.org/
  - § 3.2.26 Buffer source types
  - § 3.2.24 Promise types
  - § 3.2.21 object type

---

## Future Work

1. **Complete Promise implementation** - Async state machine, then/catch/finally chains
2. **Full DataView API** - All getter/setter methods (getFloat64, getBigInt64, etc.)
3. **Atomic operations** - Atomics API for SharedArrayBuffer
4. **Object property model** - Property descriptors, [[Prototype]] chain
5. **Performance optimizations** - SIMD for bulk operations, inline caching

---

## Contributing

When modifying types in this module:

1. ✅ **Verify IDL usage** - Check that the type is actually used in webref/ed/idl/
2. ✅ **Match ECMAScript spec** - Implementation must follow spec algorithms
3. ✅ **Add tests** - Cover core functionality and edge cases
4. ✅ **Update this README** - Document changes and implementation status
5. ✅ **Update root.zig** - Export new types in appropriate section
