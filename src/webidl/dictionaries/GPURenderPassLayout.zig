//! WebIDL dictionary: GPURenderPassLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassLayout = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorFormats: []const *const anyopaque,
    depthStencilFormat: ?enums.GPUTextureFormat = null,
    sampleCount: ?typedefs.GPUSize32 = null,
};
