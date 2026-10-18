//! WebIDL dictionary: GPUExtent3DDict
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUExtent3DDict = struct {
    width: typedefs.GPUIntegerCoordinate,
    height: ?typedefs.GPUIntegerCoordinate = null,
    depthOrArrayLayers: ?typedefs.GPUIntegerCoordinate = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "height", .{ .number = 1 } },
        .{ "depthOrArrayLayers", .{ .number = 1 } },
    };
};
