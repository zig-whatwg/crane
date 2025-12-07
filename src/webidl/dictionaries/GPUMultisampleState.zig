//! WebIDL dictionary: GPUMultisampleState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPUMultisampleState = struct {
    count: ?typedefs.GPUSize32 = null,
    mask: ?typedefs.GPUSampleMask = null,
    alphaToCoverageEnabled: ?bool = null,
};
