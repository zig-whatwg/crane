//! WebIDL dictionary: XRMediaCylinderLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRMediaLayerInit = @import("XRMediaLayerInit.zig").XRMediaLayerInit;

pub const XRMediaCylinderLayerInit = struct {
    // Inherited from XRMediaLayerInit
    base: XRMediaLayerInit,

    transform: ?*runtime.Instance = null,
    radius: ?f32 = null,
    centralAngle: ?f32 = null,
    aspectRatio: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "radius", "centralAngle", "aspectRatio" };
};
