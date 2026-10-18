//! WebIDL dictionary: GPUStorageTextureBindingLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUStorageTextureBindingLayout = struct {
    access: ?enums.GPUStorageTextureAccess = null,
    format: enums.GPUTextureFormat,
    viewDimension: ?enums.GPUTextureViewDimension = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "access", .{ .string = "write-only" } },
        .{ "viewDimension", .{ .string = "2d" } },
    };
};
