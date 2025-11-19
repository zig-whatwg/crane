//! ECMAScript Uint32Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Uint32Array: TypedArray of 32-bit unsigned integers
pub const Uint32Array = TypedArray(u32);
