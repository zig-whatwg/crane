//! WebIDL dictionary: GPUBlendComponent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const GPUBlendComponent = struct {
    operation: ?enums.GPUBlendOperation = null,
    srcFactor: ?enums.GPUBlendFactor = null,
    dstFactor: ?enums.GPUBlendFactor = null,
};
