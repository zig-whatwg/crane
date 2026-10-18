//! WebIDL dictionary: GPUBufferBinding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUBufferBinding = struct {
    buffer: *runtime.Instance,
    offset: ?typedefs.GPUSize64 = null,
    size: ?typedefs.GPUSize64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "offset", .{ .number = 0 } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "buffer", "GPUBuffer" },
    };
};
