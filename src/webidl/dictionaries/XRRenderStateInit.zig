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

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "baseLayer", "layers" };
};
