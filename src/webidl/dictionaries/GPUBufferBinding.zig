//! WebIDL dictionary: GPUBufferBinding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUBufferBinding = struct {
    buffer: *runtime.Instance,
    offset: ?typedefs.GPUSize64 = null,
    size: ?typedefs.GPUSize64 = null,
};
