//! ECMAScript Uint8ClampedArray
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Uint8ClampedArray: TypedArray of 8-bit unsigned integers (clamped)
pub const Uint8ClampedArray = TypedArray(u8);
