//! WebIDL dictionary: GPUStencilFaceState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUStencilFaceState = struct {
    compare: ?enums.GPUCompareFunction = null,
    failOp: ?enums.GPUStencilOperation = null,
    depthFailOp: ?enums.GPUStencilOperation = null,
    passOp: ?enums.GPUStencilOperation = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "compare", .{ .string = "always" } },
        .{ "failOp", .{ .string = "keep" } },
        .{ "depthFailOp", .{ .string = "keep" } },
        .{ "passOp", .{ .string = "keep" } },
    };
};
