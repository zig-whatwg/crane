//! WebIDL dictionary: GPURenderPassDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const GPURenderPassTimestampWrites = @import("GPURenderPassTimestampWrites.zig").GPURenderPassTimestampWrites;
const GPURenderPassDepthStencilAttachment = @import("GPURenderPassDepthStencilAttachment.zig").GPURenderPassDepthStencilAttachment;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorAttachments: []const *const anyopaque,
    depthStencilAttachment: ?GPURenderPassDepthStencilAttachment = null,
    occlusionQuerySet: ?*runtime.Instance = null,
    timestampWrites: ?GPURenderPassTimestampWrites = null,
    maxDrawCount: ?typedefs.GPUSize64 = null,
};
