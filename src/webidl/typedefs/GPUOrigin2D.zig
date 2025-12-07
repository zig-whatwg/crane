//! WebIDL typedef: GPUOrigin2D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const GPUOrigin2D = union(enum) {
    gpuinteger_coordinate_sequence: []const typedefs.GPUIntegerCoordinate,
    gpuorigin2ddict: dictionaries.GPUOrigin2DDict,
};
