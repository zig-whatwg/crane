//! WebIDL dictionary: PushPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const PushPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    userVisibleOnly: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "userVisibleOnly", .{ .boolean = false } },
    };
};
