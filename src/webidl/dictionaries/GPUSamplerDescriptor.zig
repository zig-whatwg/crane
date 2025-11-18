//! WebIDL dictionary: GPUSamplerDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUSamplerDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    addressModeU: ?anyopaque = null,
    addressModeV: ?anyopaque = null,
    addressModeW: ?anyopaque = null,
    magFilter: ?anyopaque = null,
    minFilter: ?anyopaque = null,
    mipmapFilter: ?anyopaque = null,
    lodMinClamp: ?f32 = null,
    lodMaxClamp: ?f32 = null,
    compare: ?anyopaque = null,
    maxAnisotropy: ?u16 = null,
};
