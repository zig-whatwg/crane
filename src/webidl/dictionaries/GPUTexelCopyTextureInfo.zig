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

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "texture", "GPUTexture" },
    };
};
