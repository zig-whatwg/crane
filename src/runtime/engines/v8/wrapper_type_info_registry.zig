//! WrapperTypeInfo Registry - Stub implementation
//!
//! This file provides a registry for looking up WrapperTypeInfo by interface name.
//! TODO: Full implementation should be generated from WebIDL definitions.

const std = @import("std");
const wrapper_type_info = @import("wrapper_type_info.zig");
pub const WrapperTypeInfo = wrapper_type_info.WrapperTypeInfo;

/// Get WrapperTypeInfo for an interface by name
pub fn getWrapperTypeInfoByName(name: []const u8) ?*const WrapperTypeInfo {
    // Stub: Return null for now
    // Full implementation would look up in a generated registry
    _ = name;
    return null;
}

/// Check if stored_type is a subclass of expected_type
pub fn isSubclassOf(stored_type: *const WrapperTypeInfo, expected_type: *const WrapperTypeInfo) bool {
    // Delegate to WrapperTypeInfo's isSubclassOf method
    return stored_type.isSubclassOf(expected_type);
}
