//! WebIDL dictionary: GPUTextureDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    size: *const anyopaque,
    mipLevelCount: ?*const anyopaque = null,
    sampleCount: ?*const anyopaque = null,
    dimension: ?*const anyopaque = null,
    format: *const anyopaque,
    usage: *const anyopaque,
    viewFormats: ?*const anyopaque = null,
};
