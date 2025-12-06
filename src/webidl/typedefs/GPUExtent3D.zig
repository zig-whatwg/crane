//! WebIDL typedef: GPUExtent3D
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const GPUExtent3D = union(enum) {
    gpuinteger_coordinate_sequence: []const typedefs.GPUIntegerCoordinate,
    gpuextent3ddict: *runtime.Instance,
};
