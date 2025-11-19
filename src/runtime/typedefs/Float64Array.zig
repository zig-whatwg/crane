//! ECMAScript Float64Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Float64Array: TypedArray of 64-bit IEEE floating point numbers
pub const Float64Array = TypedArray(f64);
