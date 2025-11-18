//! WebIDL dictionary: GPURenderPassDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorAttachments: anyopaque,
    depthStencilAttachment: ?anyopaque = null,
    occlusionQuerySet: ?anyopaque = null,
    timestampWrites: ?anyopaque = null,
    maxDrawCount: ?anyopaque = null,
};
