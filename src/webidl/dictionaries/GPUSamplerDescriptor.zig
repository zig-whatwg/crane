//! WebIDL dictionary: GPUSamplerDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUSamplerDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    addressModeU: ?*const anyopaque = null,
    addressModeV: ?*const anyopaque = null,
    addressModeW: ?*const anyopaque = null,
    magFilter: ?*const anyopaque = null,
    minFilter: ?*const anyopaque = null,
    mipmapFilter: ?*const anyopaque = null,
    lodMinClamp: ?f32 = null,
    lodMaxClamp: ?f32 = null,
    compare: ?*const anyopaque = null,
    maxAnisotropy: ?u16 = null,
};
