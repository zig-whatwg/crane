//! WebIDL dictionary: GPUBlendComponent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUBlendComponent = struct {
    operation: ?enums.GPUBlendOperation = null,
    srcFactor: ?enums.GPUBlendFactor = null,
    dstFactor: ?enums.GPUBlendFactor = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "operation", .{ .string = "add" } },
        .{ "srcFactor", .{ .string = "one" } },
        .{ "dstFactor", .{ .string = "zero" } },
    };
};
