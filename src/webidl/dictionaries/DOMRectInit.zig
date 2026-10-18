//! WebIDL dictionary: DOMRectInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DOMRectInit = struct {
    x: ?f64 = null,
    y: ?f64 = null,
    width: ?f64 = null,
    height: ?f64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "x", .{ .number = 0 } },
        .{ "y", .{ .number = 0 } },
        .{ "width", .{ .number = 0 } },
        .{ "height", .{ .number = 0 } },
    };
};
