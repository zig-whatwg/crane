//! WebIDL dictionary: FileSystemPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const FileSystemPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    handle: *runtime.Instance,
    mode: ?enums.FileSystemPermissionMode = null,
};
