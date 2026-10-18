//! WebIDL dictionary: GPUVertexBufferLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUVertexAttribute = @import("GPUVertexAttribute.zig").GPUVertexAttribute;

pub const GPUVertexBufferLayout = struct {
    arrayStride: typedefs.GPUSize64,
    stepMode: ?enums.GPUVertexStepMode = null,
    attributes: []const GPUVertexAttribute,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "stepMode", .{ .string = "vertex" } },
    };
};
