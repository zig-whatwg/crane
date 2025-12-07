//! WebIDL dictionary: XRLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRLayerInit = struct {
    space: *runtime.Instance,
    colorFormat: ?typedefs.GLenum = null,
    depthFormat: ?typedefs.GLenum = null,
    mipLevels: ?u32 = null,
    viewPixelWidth: u32,
    viewPixelHeight: u32,
    layout: ?enums.XRLayerLayout = null,
    isStatic: ?bool = null,
    clearOnAccess: ?bool = null,
};
