//! WebIDL dictionary: GPUBindGroupDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GPUBindGroupEntry = @import("GPUBindGroupEntry.zig").GPUBindGroupEntry;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUBindGroupDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    layout: *runtime.Instance,
    entries: []const GPUBindGroupEntry,
};
