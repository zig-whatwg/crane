//! WebIDL dictionary: GPUTextureViewDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureViewDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    format: ?anyopaque = null,
    dimension: ?anyopaque = null,
    usage: ?anyopaque = null,
    aspect: ?anyopaque = null,
    baseMipLevel: ?anyopaque = null,
    mipLevelCount: ?anyopaque = null,
    baseArrayLayer: ?anyopaque = null,
    arrayLayerCount: ?anyopaque = null,
    swizzle: ?runtime.DOMString = null,
};
