//! WebIDL dictionary: GPURenderPassLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPURenderPassLayout = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    colorFormats: anyopaque,
    depthStencilFormat: ?anyopaque = null,
    sampleCount: ?anyopaque = null,
};
