//! ECMAScript Int8Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Int8Array: TypedArray of 8-bit signed integers
pub const Int8Array = TypedArray(i8);
