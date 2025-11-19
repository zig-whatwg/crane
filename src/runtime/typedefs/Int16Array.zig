//! ECMAScript Int16Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const TypedArray = @import("TypedArray.zig").TypedArray;

/// Int16Array: TypedArray of 16-bit signed integers
pub const Int16Array = TypedArray(i16);
