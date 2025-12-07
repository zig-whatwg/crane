//! WebIDL dictionary: GPUColorTargetState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUBlendState = @import("GPUBlendState.zig").GPUBlendState;

pub const GPUColorTargetState = struct {
    format: enums.GPUTextureFormat,
    blend: ?GPUBlendState = null,
    writeMask: ?typedefs.GPUColorWriteFlags = null,
};
