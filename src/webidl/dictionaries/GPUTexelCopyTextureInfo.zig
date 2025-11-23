//! WebIDL dictionary: GPUTexelCopyTextureInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUTexelCopyTextureInfo = struct {
    texture: *const anyopaque,
    mipLevel: ?*const anyopaque = null,
    origin: ?*const anyopaque = null,
    aspect: ?*const anyopaque = null,
};
