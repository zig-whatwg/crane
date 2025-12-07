//! WebIDL dictionary: GPUBufferDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUBufferDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    size: typedefs.GPUSize64,
    usage: typedefs.GPUBufferUsageFlags,
    mappedAtCreation: ?bool = null,
};
