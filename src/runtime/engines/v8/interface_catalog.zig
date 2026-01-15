//! Interface Catalog - Stub implementation
//!
//! This file provides a catalog of all WebIDL interfaces for V8 bindings.
//! TODO: Full implementation should be generated from WebIDL definitions.

const std = @import("std");

/// Represents an interface entry in the catalog
pub const InterfaceEntry = struct {
    name: []const u8,
    has_constructor: bool = false,
};

/// Invalid index constant for lookups
pub const INVALID_INDEX: usize = std.math.maxInt(usize);

/// Look up an interface by name at runtime
pub fn indexOfByNameRuntime(name: []const u8) usize {
    // Stub: Return invalid index for now
    // Full implementation would use a hash map or binary search
    _ = name;
    return INVALID_INDEX;
}

/// Get list of valid interfaces for constructor binding
pub fn getValidInterfaces() []const InterfaceEntry {
    // Stub: Return empty list
    // Full implementation would return all constructable interfaces
    return &[_]InterfaceEntry{};
}
