//! WebIDL dictionary: XRMediaCylinderLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRMediaLayerInit = @import("XRMediaLayerInit.zig").XRMediaLayerInit;

pub const XRMediaCylinderLayerInit = struct {
    // Inherited from XRMediaLayerInit
    base: XRMediaLayerInit,

    transform: ?anyopaque = null,
    radius: ?f32 = null,
    centralAngle: ?f32 = null,
    aspectRatio: ?anyopaque = null,
};
