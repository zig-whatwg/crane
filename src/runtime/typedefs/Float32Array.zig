//! ECMAScript Float32Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Float32Array: TypedArray of 32-bit IEEE floating point numbers
pub const Float32Array = TypedArray(f32);
