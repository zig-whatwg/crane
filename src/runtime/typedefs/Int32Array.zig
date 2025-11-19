//! ECMAScript Int32Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Int32Array: TypedArray of 32-bit signed integers
pub const Int32Array = TypedArray(i32);
