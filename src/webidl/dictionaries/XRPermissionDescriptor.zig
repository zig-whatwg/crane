//! WebIDL dictionary: XRPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const XRPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    mode: ?enums.XRSessionMode = null,
    requiredFeatures: ?[]const runtime.DOMString = null,
    optionalFeatures: ?[]const runtime.DOMString = null,
};
