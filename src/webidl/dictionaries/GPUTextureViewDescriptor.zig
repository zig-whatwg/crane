//! WebIDL dictionary: GPUTextureViewDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureViewDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    format: ?*const anyopaque = null,
    dimension: ?*const anyopaque = null,
    usage: ?*const anyopaque = null,
    aspect: ?*const anyopaque = null,
    baseMipLevel: ?*const anyopaque = null,
    mipLevelCount: ?*const anyopaque = null,
    baseArrayLayer: ?*const anyopaque = null,
    arrayLayerCount: ?*const anyopaque = null,
    swizzle: ?runtime.DOMString = null,
};
