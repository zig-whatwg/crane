//! WebIDL type definitions for Zig runtime
//!
//! This module re-exports all WebIDL types from the typedefs/ directory:
//! - DOMString: Union for efficient string storage (empty/interned/owned)
//! - USVString: Unicode scalar value string
//! - ByteString: ASCII byte string
//! - Primitive type aliases for clarity
//! - Parameterized types: FrozenArray, sequence, Promise, ObservableArray, record

// String types
pub const DOMString = @import("typedefs/DOMString.zig").DOMString;
pub const USVString = @import("typedefs/USVString.zig").USVString;
pub const ByteString = @import("typedefs/ByteString.zig").ByteString;

// Primitive types
const primitives = @import("typedefs/primitives.zig");
pub const Boolean = primitives.Boolean;
pub const Byte = primitives.Byte;
pub const Octet = primitives.Octet;
pub const Short = primitives.Short;
pub const UnsignedShort = primitives.UnsignedShort;
pub const Long = primitives.Long;
pub const UnsignedLong = primitives.UnsignedLong;
pub const LongLong = primitives.LongLong;
pub const UnsignedLongLong = primitives.UnsignedLongLong;
pub const Float = primitives.Float;
pub const Double = primitives.Double;
pub const UnrestrictedFloat = primitives.UnrestrictedFloat;
pub const UnrestrictedDouble = primitives.UnrestrictedDouble;
pub const Any = primitives.Any;
pub const Object = primitives.Object;

// Parameterized types
pub const FrozenArray = @import("typedefs/FrozenArray.zig").FrozenArray;
pub const sequence = @import("typedefs/sequence.zig").sequence;
pub const Promise = @import("typedefs/Promise.zig").Promise;
pub const ObservableArray = @import("typedefs/ObservableArray.zig").ObservableArray;
pub const record = @import("typedefs/record.zig").record;

// JavaScript built-in buffer types (wrappers for V8 ArrayBuffer/TypedArray)
// These represent V8's binary data types - the actual data lives in V8's heap
pub const ArrayBuffer = @import("typedefs/ArrayBuffer.zig").ArrayBuffer;
pub const SharedArrayBuffer = @import("typedefs/SharedArrayBuffer.zig").SharedArrayBuffer;
pub const DataView = @import("typedefs/DataView.zig").DataView;
pub const Int8Array = @import("typedefs/TypedArrays.zig").Int8Array;
pub const Int16Array = @import("typedefs/TypedArrays.zig").Int16Array;
pub const Int32Array = @import("typedefs/TypedArrays.zig").Int32Array;
pub const Uint8Array = @import("typedefs/TypedArrays.zig").Uint8Array;
pub const Uint8ClampedArray = @import("typedefs/TypedArrays.zig").Uint8ClampedArray;
pub const Uint16Array = @import("typedefs/TypedArrays.zig").Uint16Array;
pub const Uint32Array = @import("typedefs/TypedArrays.zig").Uint32Array;
pub const Float32Array = @import("typedefs/TypedArrays.zig").Float32Array;
pub const Float64Array = @import("typedefs/TypedArrays.zig").Float64Array;
pub const BigInt64Array = @import("typedefs/TypedArrays.zig").BigInt64Array;
pub const BigUint64Array = @import("typedefs/TypedArrays.zig").BigUint64Array;

// Re-export tests
test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
