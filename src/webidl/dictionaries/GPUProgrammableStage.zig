//! WebIDL dictionary: GPUProgrammableStage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUProgrammableStage = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    module: *runtime.Instance,
    entryPoint: ?runtime.USVString = null,
    constants: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.USVString,
        value: typedefs.GPUPipelineConstantValue,
    } = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "constants", .empty_dictionary },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "module", "GPUShaderModule" },
    };
};
