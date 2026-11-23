//! WebIDL dictionary: GPUColorTargetState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUBlendState = @import("GPUBlendState.zig").GPUBlendState;

pub const GPUColorTargetState = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    format: enums.GPUTextureFormat,
    blend: ?GPUBlendState = null,
    writeMask: ?typedefs.GPUColorWriteFlags = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "writeMask", .{ .number = 15 } },
    };
};
