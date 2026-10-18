//! WebIDL dictionary: LayoutOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LayoutOptions = struct {
    childDisplay: ?enums.ChildDisplayType = null,
    sizing: ?enums.LayoutSizingMode = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "childDisplay", .{ .string = "block" } },
        .{ "sizing", .{ .string = "block-like" } },
    };
};
