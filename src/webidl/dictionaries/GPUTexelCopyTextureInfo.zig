//! WebIDL dictionary: GPUTexelCopyTextureInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPUTexelCopyTextureInfo = struct {
    texture: *runtime.Instance,
    mipLevel: ?typedefs.GPUIntegerCoordinate = null,
    origin: ?typedefs.GPUOrigin3D = null,
    aspect: ?enums.GPUTextureAspect = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mipLevel", .{ .number = 0 } },
        .{ "origin", .empty_dictionary },
        .{ "aspect", .{ .string = "all" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "texture", "GPUTexture" },
    };
};
