//! WebIDL dictionary: GPUCopyExternalImageDestInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const GPUTexelCopyTextureInfo = @import("GPUTexelCopyTextureInfo.zig").GPUTexelCopyTextureInfo;

pub const GPUCopyExternalImageDestInfo = struct {
    // Inherited from GPUTexelCopyTextureInfo
    base: GPUTexelCopyTextureInfo,

    colorSpace: ?enums.PredefinedColorSpace = null,
    premultipliedAlpha: ?bool = null,
};
