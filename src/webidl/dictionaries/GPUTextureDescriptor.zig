//! WebIDL dictionary: GPUTextureDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    size: typedefs.GPUExtent3D,
    mipLevelCount: ?typedefs.GPUIntegerCoordinate = null,
    sampleCount: ?typedefs.GPUSize32 = null,
    dimension: ?enums.GPUTextureDimension = null,
    format: enums.GPUTextureFormat,
    usage: typedefs.GPUTextureUsageFlags,
    viewFormats: ?[]const enums.GPUTextureFormat = null,
    textureBindingViewDimension: ?enums.GPUTextureViewDimension = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mipLevelCount", .{ .number = 1 } },
        .{ "sampleCount", .{ .number = 1 } },
        .{ "dimension", .{ .string = "2d" } },
        .{ "viewFormats", .empty_sequence },
    };
};
