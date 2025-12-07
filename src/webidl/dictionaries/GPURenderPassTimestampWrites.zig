//! WebIDL dictionary: GPURenderPassTimestampWrites
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPURenderPassTimestampWrites = struct {
    querySet: *runtime.Instance,
    beginningOfPassWriteIndex: ?typedefs.GPUSize32 = null,
    endOfPassWriteIndex: ?typedefs.GPUSize32 = null,
};
