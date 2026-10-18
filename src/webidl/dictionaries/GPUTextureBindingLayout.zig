//! WebIDL dictionary: GPUTextureBindingLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUTextureBindingLayout = struct {
    sampleType: ?enums.GPUTextureSampleType = null,
    viewDimension: ?enums.GPUTextureViewDimension = null,
    multisampled: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "sampleType", .{ .string = "float" } },
        .{ "viewDimension", .{ .string = "2d" } },
        .{ "multisampled", .{ .boolean = false } },
    };
};
