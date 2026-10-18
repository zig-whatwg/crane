//! WebIDL dictionary: FilePickerAcceptType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FilePickerAcceptType = struct {
    description: ?runtime.USVString = null,
    accept: ?[]const struct { key: runtime.USVString, value: runtime.JSValue } = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "description", .{ .string = "" } },
    };
};
