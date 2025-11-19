//! sequence<T> - Value-based array
//!
//! WebIDL sequence<T> represents an array passed by value (copied).
//! Per the spec: "sequence types are lists of values that are passed by value"
//!
//! In Zig, this maps to an owned slice []T that must be freed.
//!
//! Generic function to create the type (used in generated code):

/// sequence<T> - Value-based array type
pub fn sequence(comptime T: type) type {
    return []T;
}
