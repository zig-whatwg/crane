//! WebIDL dictionary: XRSessionSupportedPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const XRSessionSupportedPermissionDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    mode: ?enums.XRSessionMode = null,
};
