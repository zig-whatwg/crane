//! WebIDL dictionary: GPUCopyExternalImageSourceInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GPUCopyExternalImageSourceInfo = struct {
    source: typedefs.GPUCopyExternalImageSource,
    origin: ?typedefs.GPUOrigin2D = null,
    flipY: ?bool = null,
};
