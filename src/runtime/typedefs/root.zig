//! ECMAScript Built-in Types (Used in WebIDL)
//!
//! This module provides Zig implementations of ECMAScript built-in types that are
//! explicitly referenced in WebIDL files at /Users/bcardarella/projects/webref/ed/idl/
//!
//! These types form the JavaScript runtime layer that WebIDL interfaces with.
//!
//! # Architecture
//!
//! **Layer 1: Infra** - WHATWG primitives (String, List, Map, etc.)
//! **Layer 2: Runtime (this module)** - ECMAScript built-ins used in IDL (ArrayBuffer, Promise, etc.)
//! **Layer 3: WebIDL Typedefs** - WebIDL typedef unions (BufferSource, ArrayBufferView, etc.)
//!
//! # Types Included (Based on IDL Usage)
//!
//! ## Promise Type (595 occurrences in IDL)
//! - Promise<T>
//!
//! ## Buffer Types (95 occurrences)
//! - ArrayBuffer
//! - SharedArrayBuffer (for [AllowShared] extended attribute)
//!
//! ## Typed Array Types (87 occurrences)
//! - Int8Array, Int16Array, Int32Array
//! - Uint8Array, Uint16Array, Uint32Array, Uint8ClampedArray
//! - BigInt64Array, BigUint64Array
//! - Float32Array, Float64Array
//! - TypedArray(T) generic
//!
//! ## Buffer View Types (17 occurrences)
//! - DataView
//!
//! ## Generic Object Type
//! - Object (for IDL `object` type)
//!
//! # Usage
//!
//! ```zig
//! const runtime_types = @import("runtime/typedefs");
//!
//! // Create an ArrayBuffer
//! var buffer = try runtime_types.ArrayBuffer.init(allocator, 1024);
//! defer buffer.deinit(allocator);
//!
//! // Create a typed array view
//! var view = try runtime_types.Uint8Array.init(&buffer, 0, 256);
//!
//! // Use Promise
//! var promise = runtime_types.Promise(u32).init();
//! promise.resolve(42);
//! ```

const std = @import("std");

// ============================================================================
// Promise Type (ECMAScript § 27.2)
// ============================================================================

pub const Promise = @import("Promise.zig").Promise;

// ============================================================================
// Buffer Types (ECMAScript § 25)
// ============================================================================

pub const ArrayBuffer = @import("ArrayBuffer.zig").ArrayBuffer;
pub const SharedArrayBuffer = @import("SharedArrayBuffer.zig").SharedArrayBuffer;

// ============================================================================
// Typed Array Types (ECMAScript § 22.2)
// ============================================================================

pub const TypedArray = @import("TypedArray.zig").TypedArray;
pub const Int8Array = @import("Int8Array.zig").Int8Array;
pub const Int16Array = @import("Int16Array.zig").Int16Array;
pub const Int32Array = @import("Int32Array.zig").Int32Array;
pub const Uint8Array = @import("Uint8Array.zig").Uint8Array;
pub const Uint16Array = @import("Uint16Array.zig").Uint16Array;
pub const Uint32Array = @import("Uint32Array.zig").Uint32Array;
pub const Uint8ClampedArray = @import("Uint8ClampedArray.zig").Uint8ClampedArray;
pub const BigInt64Array = @import("BigInt64Array.zig").BigInt64Array;
pub const BigUint64Array = @import("BigUint64Array.zig").BigUint64Array;
pub const Float32Array = @import("Float32Array.zig").Float32Array;
pub const Float64Array = @import("Float64Array.zig").Float64Array;

// ============================================================================
// Buffer View Types (ECMAScript § 25.3)
// ============================================================================

pub const DataView = @import("DataView.zig").DataView;

// ============================================================================
// Generic Object Type
// ============================================================================

pub const Object = @import("Object.zig").Object;

// ============================================================================
// Tests
// ============================================================================

test {
    std.testing.refAllDecls(@This());
}
