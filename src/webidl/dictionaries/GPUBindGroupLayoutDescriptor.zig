//! WebIDL dictionary: GPUBindGroupLayoutDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GPUBindGroupLayoutEntry = @import("GPUBindGroupLayoutEntry.zig").GPUBindGroupLayoutEntry;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUBindGroupLayoutDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    entries: []const GPUBindGroupLayoutEntry,
};
