//! WebIDL dictionary: GPUBufferBindingLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPUBufferBindingLayout = struct {
    type: ?enums.GPUBufferBindingType = null,
    hasDynamicOffset: ?bool = null,
    minBindingSize: ?typedefs.GPUSize64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "uniform" } },
        .{ "hasDynamicOffset", .{ .boolean = false } },
        .{ "minBindingSize", .{ .number = 0 } },
    };
};
