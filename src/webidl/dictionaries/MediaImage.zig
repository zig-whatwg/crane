//! WebIDL dictionary: MediaImage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaImage = struct {
    src: runtime.USVString,
    sizes: ?runtime.DOMString = null,
    type: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "sizes", .{ .string = "" } },
        .{ "type", .{ .string = "" } },
    };
};
