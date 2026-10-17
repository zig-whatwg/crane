//! WebIDL dictionary: GPUBindGroupDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUBindGroupEntry = @import("GPUBindGroupEntry.zig").GPUBindGroupEntry;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUBindGroupDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    layout: *runtime.Instance,
    entries: []const GPUBindGroupEntry,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "layout", "GPUBindGroupLayout" },
    };
};
