//! WebIDL dictionary: XRMediaQuadLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRMediaLayerInit = @import("XRMediaLayerInit.zig").XRMediaLayerInit;

pub const XRMediaQuadLayerInit = struct {
    // Inherited from XRMediaLayerInit
    base: XRMediaLayerInit,

    transform: ?*runtime.Instance = null,
    width: ?f32 = null,
    height: ?f32 = null,
};
