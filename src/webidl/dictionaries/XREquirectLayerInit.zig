//! WebIDL dictionary: XREquirectLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XREquirectLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    textureType: ?anyopaque = null,
    transform: ?anyopaque = null,
    radius: ?f32 = null,
    centralHorizontalAngle: ?f32 = null,
    upperVerticalAngle: ?f32 = null,
    lowerVerticalAngle: ?f32 = null,
};
