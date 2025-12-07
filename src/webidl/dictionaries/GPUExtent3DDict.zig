//! WebIDL dictionary: GPUExtent3DDict
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPUExtent3DDict = struct {
    width: typedefs.GPUIntegerCoordinate,
    height: ?typedefs.GPUIntegerCoordinate = null,
    depthOrArrayLayers: ?typedefs.GPUIntegerCoordinate = null,
};
