//! WebIDL dictionary: DirectoryPickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const DirectoryPickerOptions = struct {
    id: ?runtime.DOMString = null,
    startIn: ?typedefs.StartInDirectory = null,
    mode: ?enums.FileSystemPermissionMode = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mode", .{ .string = "read" } },
    };
};
