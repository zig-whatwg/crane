//! WebIDL dictionary: GPURenderPassDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorAttachments: *const anyopaque,
    depthStencilAttachment: ?*const anyopaque = null,
    occlusionQuerySet: ?*const anyopaque = null,
    timestampWrites: ?*const anyopaque = null,
    maxDrawCount: ?*const anyopaque = null,
};
