//! WebIDL dictionary: FileSystemFlags
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FileSystemFlags = struct {
    create: ?bool = null,
    exclusive: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "create", .{ .boolean = false } },
        .{ "exclusive", .{ .boolean = false } },
    };
};
