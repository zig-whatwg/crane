//! WebIDL dictionary: GPUCopyExternalImageSourceInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUCopyExternalImageSourceInfo = struct {
    source: *const anyopaque,
    origin: ?*const anyopaque = null,
    flipY: ?bool = null,
};
