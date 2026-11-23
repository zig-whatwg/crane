//! WebIDL dictionary: GPUBindGroupLayoutDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUBindGroupLayoutEntry = @import("GPUBindGroupLayoutEntry.zig").GPUBindGroupLayoutEntry;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUBindGroupLayoutDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    entries: []const GPUBindGroupLayoutEntry,
};
