//! WebIDL dictionary: XRProjectionLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRProjectionLayerInit = struct {
    textureType: ?enums.XRTextureType = null,
    colorFormat: ?typedefs.GLenum = null,
    depthFormat: ?typedefs.GLenum = null,
    scaleFactor: ?f64 = null,
    clearOnAccess: ?bool = null,
};
