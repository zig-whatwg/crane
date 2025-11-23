//! WebIDL dictionary: XRLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRLayerInit = struct {
    space: *const anyopaque,
    colorFormat: ?*const anyopaque = null,
    depthFormat: ?*const anyopaque = null,
    mipLevels: ?u32 = null,
    viewPixelWidth: u32,
    viewPixelHeight: u32,
    layout: ?*const anyopaque = null,
    isStatic: ?bool = null,
    clearOnAccess: ?bool = null,
};
