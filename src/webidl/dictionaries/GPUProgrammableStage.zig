//! WebIDL dictionary: GPUProgrammableStage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUProgrammableStage = struct {
    module: *runtime.Instance,
    entryPoint: ?runtime.USVString = null,
    constants: ?[]const struct { key: runtime.USVString, value: typedefs.GPUPipelineConstantValue } = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "module", "GPUShaderModule" },
    };
};
