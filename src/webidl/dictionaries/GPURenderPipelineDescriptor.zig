//! WebIDL dictionary: GPURenderPipelineDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUPipelineDescriptorBase = @import("GPUPipelineDescriptorBase.zig").GPUPipelineDescriptorBase;

pub const GPURenderPipelineDescriptor = struct {
    // Inherited from GPUPipelineDescriptorBase
    base: GPUPipelineDescriptorBase,

    vertex: anyopaque,
    primitive: ?anyopaque = null,
    depthStencil: ?anyopaque = null,
    multisample: ?anyopaque = null,
    fragment: ?anyopaque = null,
};
