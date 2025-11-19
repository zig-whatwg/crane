//! ECMAScript Uint8Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Uint8Array: TypedArray of 8-bit unsigned integers
pub const Uint8Array = TypedArray(u8);
