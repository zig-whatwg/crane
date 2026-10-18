//! WebIDL dictionary: FileSystemPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const FileSystemPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    handle: *runtime.Instance,
    mode: ?enums.FileSystemPermissionMode = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mode", .{ .string = "read" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "handle", "FileSystemHandle" },
    };
};
