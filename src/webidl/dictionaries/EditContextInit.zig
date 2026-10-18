//! WebIDL dictionary: EditContextInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EditContextInit = struct {
    text: ?runtime.DOMString = null,
    selectionStart: ?u32 = null,
    selectionEnd: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "text", .{ .string = "" } },
        .{ "selectionStart", .{ .number = 0 } },
        .{ "selectionEnd", .{ .number = 0 } },
    };
};
