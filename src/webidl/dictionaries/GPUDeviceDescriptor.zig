//! WebIDL dictionary: GPUDeviceDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUQueueDescriptor = @import("GPUQueueDescriptor.zig").GPUQueueDescriptor;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUDeviceDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    requiredFeatures: ?[]const enums.GPUFeatureName = null,
    requiredLimits: ?[]const struct { key: runtime.DOMString, value: runtime.JSValue } = null,
    defaultQueue: ?GPUQueueDescriptor = null,
};
