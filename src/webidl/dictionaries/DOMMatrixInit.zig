//! WebIDL dictionary: DOMMatrixInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DOMMatrix2DInit = @import("DOMMatrix2DInit.zig").DOMMatrix2DInit;

pub const DOMMatrixInit = struct {
    // Inherited from DOMMatrix2DInit
    base: DOMMatrix2DInit,

    m13: ?f64 = null,
    m14: ?f64 = null,
    m23: ?f64 = null,
    m24: ?f64 = null,
    m31: ?f64 = null,
    m32: ?f64 = null,
    m33: ?f64 = null,
    m34: ?f64 = null,
    m43: ?f64 = null,
    m44: ?f64 = null,
    is2D: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "m13", .{ .number = 0 } },
        .{ "m14", .{ .number = 0 } },
        .{ "m23", .{ .number = 0 } },
        .{ "m24", .{ .number = 0 } },
        .{ "m31", .{ .number = 0 } },
        .{ "m32", .{ .number = 0 } },
        .{ "m33", .{ .number = 1 } },
        .{ "m34", .{ .number = 0 } },
        .{ "m43", .{ .number = 0 } },
        .{ "m44", .{ .number = 1 } },
    };
};
