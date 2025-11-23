//! WebIDL dictionary: XRPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const XRPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    mode: ?*const anyopaque = null,
    requiredFeatures: ?*const anyopaque = null,
    optionalFeatures: ?*const anyopaque = null,
};
