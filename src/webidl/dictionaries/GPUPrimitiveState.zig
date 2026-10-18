//! WebIDL dictionary: GPUPrimitiveState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUPrimitiveState = struct {
    topology: ?enums.GPUPrimitiveTopology = null,
    stripIndexFormat: ?enums.GPUIndexFormat = null,
    frontFace: ?enums.GPUFrontFace = null,
    cullMode: ?enums.GPUCullMode = null,
    unclippedDepth: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "topology", .{ .string = "triangle-list" } },
        .{ "frontFace", .{ .string = "ccw" } },
        .{ "cullMode", .{ .string = "none" } },
        .{ "unclippedDepth", .{ .boolean = false } },
    };
};
