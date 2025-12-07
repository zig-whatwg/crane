//! WebIDL dictionary: GPUSamplerDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUSamplerDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    addressModeU: ?enums.GPUAddressMode = null,
    addressModeV: ?enums.GPUAddressMode = null,
    addressModeW: ?enums.GPUAddressMode = null,
    magFilter: ?enums.GPUFilterMode = null,
    minFilter: ?enums.GPUFilterMode = null,
    mipmapFilter: ?enums.GPUMipmapFilterMode = null,
    lodMinClamp: ?f32 = null,
    lodMaxClamp: ?f32 = null,
    compare: ?enums.GPUCompareFunction = null,
    maxAnisotropy: ?u16 = null,
};
