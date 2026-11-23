//! WebIDL dictionary: ConvertCoordinateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ConvertCoordinateOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    fromBox: ?enums.CSSBoxType = null,
    toBox: ?enums.CSSBoxType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "fromBox", .{ .string = "border" } },
        .{ "toBox", .{ .string = "border" } },
    };
};
