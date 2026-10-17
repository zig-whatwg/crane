//! WebIDL dictionary: GPUPipelineLayoutDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUPipelineLayoutDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    bindGroupLayouts: []const runtime.JSValue,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "bindGroupLayouts", "GPUBindGroupLayout" },
    };
};
