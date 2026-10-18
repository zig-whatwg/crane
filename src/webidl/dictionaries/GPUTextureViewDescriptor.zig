//! WebIDL dictionary: GPUTextureViewDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUTextureViewDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    format: ?enums.GPUTextureFormat = null,
    dimension: ?enums.GPUTextureViewDimension = null,
    usage: ?typedefs.GPUTextureUsageFlags = null,
    aspect: ?enums.GPUTextureAspect = null,
    baseMipLevel: ?typedefs.GPUIntegerCoordinate = null,
    mipLevelCount: ?typedefs.GPUIntegerCoordinate = null,
    baseArrayLayer: ?typedefs.GPUIntegerCoordinate = null,
    arrayLayerCount: ?typedefs.GPUIntegerCoordinate = null,
    swizzle: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "usage", .{ .number = 0 } },
        .{ "aspect", .{ .string = "all" } },
        .{ "baseMipLevel", .{ .number = 0 } },
        .{ "baseArrayLayer", .{ .number = 0 } },
        .{ "swizzle", .{ .string = "rgba" } },
    };
};
