//! WebIDL dictionary: XRPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const XRPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    mode: ?anyopaque = null,
    requiredFeatures: ?anyopaque = null,
    optionalFeatures: ?anyopaque = null,
};
