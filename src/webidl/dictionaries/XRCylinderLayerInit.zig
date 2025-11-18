//! WebIDL dictionary: XRCylinderLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XRCylinderLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    textureType: ?anyopaque = null,
    transform: ?anyopaque = null,
    radius: ?f32 = null,
    centralAngle: ?f32 = null,
    aspectRatio: ?f32 = null,
};
