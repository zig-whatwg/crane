//! WebIDL dictionary: XREquirectLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XREquirectLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    textureType: ?enums.XRTextureType = null,
    transform: ?*runtime.Instance = null,
    radius: ?f32 = null,
    centralHorizontalAngle: ?f32 = null,
    upperVerticalAngle: ?f32 = null,
    lowerVerticalAngle: ?f32 = null,
};
