//! WebIDL dictionary: XRRenderStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRRenderStateInit = struct {
    depthNear: ?f64 = null,
    depthFar: ?f64 = null,
    passthroughFullyObscured: ?bool = null,
    inlineVerticalFieldOfView: ?f64 = null,
    baseLayer: ?*runtime.Instance = null,
    layers: ?[]const *runtime.Instance = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "depthNear", "depthFar", "inlineVerticalFieldOfView" };
};
