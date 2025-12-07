//! WebIDL dictionary: GPUComputePassTimestampWrites
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUComputePassTimestampWrites = struct {
    querySet: *runtime.Instance,
    beginningOfPassWriteIndex: ?typedefs.GPUSize32 = null,
    endOfPassWriteIndex: ?typedefs.GPUSize32 = null,
};
