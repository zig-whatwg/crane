//! ECMAScript Uint16Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Uint16Array: TypedArray of 16-bit unsigned integers
pub const Uint16Array = TypedArray(u16);
