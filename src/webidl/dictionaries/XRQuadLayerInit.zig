//! WebIDL dictionary: XRQuadLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XRQuadLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    transform: ?*runtime.Instance = null,
    width: ?f32 = null,
    height: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "width", "height" };
};
