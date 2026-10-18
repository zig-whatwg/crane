//! WebIDL dictionary: TextFormatInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const TextFormatInit = struct {
    rangeStart: ?u32 = null,
    rangeEnd: ?u32 = null,
    underlineStyle: ?enums.UnderlineStyle = null,
    underlineThickness: ?enums.UnderlineThickness = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "rangeStart", .{ .number = 0 } },
        .{ "rangeEnd", .{ .number = 0 } },
        .{ "underlineStyle", .{ .string = "none" } },
        .{ "underlineThickness", .{ .string = "none" } },
    };
};
