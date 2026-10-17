//! WebIDL dictionary: XRGPUEquirectLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRGPULayerInit = @import("XRGPULayerInit.zig").XRGPULayerInit;

pub const XRGPUEquirectLayerInit = struct {
    // Inherited from XRGPULayerInit
    base: XRGPULayerInit,

    transform: ?*runtime.Instance = null,
    radius: ?f32 = null,
    centralHorizontalAngle: ?f32 = null,
    upperVerticalAngle: ?f32 = null,
    lowerVerticalAngle: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "radius", "centralHorizontalAngle", "upperVerticalAngle", "lowerVerticalAngle" };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"transform"};
};
