//! WebIDL dictionary: GPURenderPipelineDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUPipelineDescriptorBase = @import("GPUPipelineDescriptorBase.zig").GPUPipelineDescriptorBase;

pub const GPURenderPipelineDescriptor = struct {
    // Inherited from GPUPipelineDescriptorBase
    base: GPUPipelineDescriptorBase,

    vertex: *const anyopaque,
    primitive: ?*const anyopaque = null,
    depthStencil: ?*const anyopaque = null,
    multisample: ?*const anyopaque = null,
    fragment: ?*const anyopaque = null,
};
