//! WebIDL dictionary: GPUCopyExternalImageDestInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUTexelCopyTextureInfo = @import("GPUTexelCopyTextureInfo.zig").GPUTexelCopyTextureInfo;

pub const GPUCopyExternalImageDestInfo = struct {
    // Inherited from GPUTexelCopyTextureInfo
    base: GPUTexelCopyTextureInfo,

    colorSpace: ?anyopaque = null,
    premultipliedAlpha: ?bool = null,
};
