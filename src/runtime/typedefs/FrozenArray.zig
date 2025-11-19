//! FrozenArray<T> - Immutable array reference
//!
//! WebIDL FrozenArray<T> represents a frozen (immutable) JavaScript array.
//! Per the spec: "FrozenArray<T> values are references to objects that hold
//! a fixed length array of unmodifiable values."
//!
//! In Zig, this maps to a const slice []const T.
//! The array is owned by the JavaScript runtime and should not be freed by Zig.
//!
//! Generic function to create the type (used in generated code):

/// FrozenArray<T> - Immutable array type
pub fn FrozenArray(comptime T: type) type {
    return []const T;
}
