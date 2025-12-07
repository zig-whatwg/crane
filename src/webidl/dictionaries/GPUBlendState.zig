//! WebIDL dictionary: GPUBlendState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GPUBlendComponent = @import("GPUBlendComponent.zig").GPUBlendComponent;

pub const GPUBlendState = struct {
    color: GPUBlendComponent,
    alpha: GPUBlendComponent,
};
