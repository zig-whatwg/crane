//! WebIDL dictionary: GPUExtent3DDict
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUExtent3DDict = struct {
    width: *const anyopaque,
    height: ?*const anyopaque = null,
    depthOrArrayLayers: ?*const anyopaque = null,
};
