//! WebIDL dictionary: GPUTexelCopyTextureInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPUTexelCopyTextureInfo = struct {
    texture: *runtime.Instance,
    mipLevel: ?typedefs.GPUIntegerCoordinate = null,
    origin: ?typedefs.GPUOrigin3D = null,
    aspect: ?enums.GPUTextureAspect = null,
};
