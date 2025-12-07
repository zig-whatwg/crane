//! WebIDL dictionary: GPUTextureViewDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureViewDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    format: ?enums.GPUTextureFormat = null,
    dimension: ?enums.GPUTextureViewDimension = null,
    usage: ?typedefs.GPUTextureUsageFlags = null,
    aspect: ?enums.GPUTextureAspect = null,
    baseMipLevel: ?typedefs.GPUIntegerCoordinate = null,
    mipLevelCount: ?typedefs.GPUIntegerCoordinate = null,
    baseArrayLayer: ?typedefs.GPUIntegerCoordinate = null,
    arrayLayerCount: ?typedefs.GPUIntegerCoordinate = null,
    swizzle: ?runtime.DOMString = null,
};
