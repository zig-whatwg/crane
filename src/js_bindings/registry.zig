//! Binding Registry
//!
//! Provides comptime-generated registry of all WebIDL bindings.
//!
//! This module automatically discovers all generated namespaces and interfaces
//! and creates binding descriptors for them using the metadata extraction system.

const std = @import("std");
const metadata = @import("metadata.zig");
const types = @import("types.zig");

/// Registry of all namespace bindings
pub const namespaces = struct {
    // NOTE: We cannot import the generated namespaces module here because
    // it contains anyopaque parameters which are not allowed in Zig 0.15.2.
    // Instead, we'll provide a manual registration API for now.
    //
    // Future: When generator is fixed to not use anyopaque parameters,
    // we can automatically extract all namespace bindings here.
};

/// Registry of all interface bindings
pub const interfaces = struct {
    // NOTE: Similar issue with interfaces - some generated interfaces
    // may have compilation issues. We'll provide manual registration for now.
    //
    // Future: Automatically extract all interface bindings.
};

/// Manual registration API for namespaces
pub fn registerNamespace(comptime NamespaceType: type) types.NamespaceBinding {
    return metadata.extractNamespaceMetadata(NamespaceType);
}

/// Manual registration API for interfaces
pub fn registerInterface(comptime InterfaceType: type) types.InterfaceBinding {
    return metadata.extractInterfaceMetadata(InterfaceType);
}

test {
    std.testing.refAllDecls(@This());
}
