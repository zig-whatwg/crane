//! WebIDL dictionary: XRRenderStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const XRRenderStateInit = struct {
    depthNear: ?f64 = null,
    depthFar: ?f64 = null,
    passthroughFullyObscured: ?bool = null,
    inlineVerticalFieldOfView: ?f64 = null,
    baseLayer: ?*runtime.Instance = null,
    layers: ?[]const *runtime.Instance = null,
};
