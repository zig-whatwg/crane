//! WebIDL dictionary: GPUTexelCopyBufferLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPUTexelCopyBufferLayout = struct {
    offset: ?typedefs.GPUSize64 = null,
    bytesPerRow: ?typedefs.GPUSize32 = null,
    rowsPerImage: ?typedefs.GPUSize32 = null,
};
