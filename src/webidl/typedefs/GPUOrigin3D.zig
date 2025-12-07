//! WebIDL typedef: GPUOrigin3D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const GPUOrigin3D = union(enum) {
    gpuinteger_coordinate_sequence: []const typedefs.GPUIntegerCoordinate,
    gpuorigin3ddict: dictionaries.GPUOrigin3DDict,
};
