//! WebIDL dictionary: DOMPointInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DOMPointInit = struct {
    x: ?f64 = null,
    y: ?f64 = null,
    z: ?f64 = null,
    w: ?f64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "x", .{ .number = 0 } },
        .{ "y", .{ .number = 0 } },
        .{ "z", .{ .number = 0 } },
        .{ "w", .{ .number = 1 } },
    };
};
