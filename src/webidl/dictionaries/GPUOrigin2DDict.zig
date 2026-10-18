//! WebIDL dictionary: GPUOrigin2DDict
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUOrigin2DDict = struct {
    x: ?typedefs.GPUIntegerCoordinate = null,
    y: ?typedefs.GPUIntegerCoordinate = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "x", .{ .number = 0 } },
        .{ "y", .{ .number = 0 } },
    };
};
