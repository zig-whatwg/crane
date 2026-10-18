//! WebIDL dictionary: GPUMultisampleState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUMultisampleState = struct {
    count: ?typedefs.GPUSize32 = null,
    mask: ?typedefs.GPUSampleMask = null,
    alphaToCoverageEnabled: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "count", .{ .number = 1 } },
        .{ "mask", .{ .number = 4294967295 } },
        .{ "alphaToCoverageEnabled", .{ .boolean = false } },
    };
};
