//! WebIDL dictionary: GPUTextureDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    size: anyopaque,
    mipLevelCount: ?anyopaque = null,
    sampleCount: ?anyopaque = null,
    dimension: ?anyopaque = null,
    format: anyopaque,
    usage: anyopaque,
    viewFormats: ?anyopaque = null,
};
