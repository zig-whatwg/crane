//! WebIDL dictionary: GPUDeviceDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUDeviceDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    requiredFeatures: ?*const anyopaque = null,
    requiredLimits: ?*const anyopaque = null,
    defaultQueue: ?*const anyopaque = null,
};
