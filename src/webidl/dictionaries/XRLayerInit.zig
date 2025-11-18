//! WebIDL dictionary: XRLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRLayerInit = struct {
    space: anyopaque,
    colorFormat: ?anyopaque = null,
    depthFormat: ?anyopaque = null,
    mipLevels: ?u32 = null,
    viewPixelWidth: u32,
    viewPixelHeight: u32,
    layout: ?anyopaque = null,
    isStatic: ?bool = null,
    clearOnAccess: ?bool = null,
};
