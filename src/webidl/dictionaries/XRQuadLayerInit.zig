//! WebIDL dictionary: XRQuadLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XRQuadLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    textureType: ?enums.XRTextureType = null,
    transform: ?*runtime.Instance = null,
    width: ?f32 = null,
    height: ?f32 = null,
};
