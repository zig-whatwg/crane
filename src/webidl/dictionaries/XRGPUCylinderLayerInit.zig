//! WebIDL dictionary: XRGPUCylinderLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRGPULayerInit = @import("XRGPULayerInit.zig").XRGPULayerInit;

pub const XRGPUCylinderLayerInit = struct {
    // Inherited from XRGPULayerInit
    base: XRGPULayerInit,

    transform: ?*runtime.Instance = null,
    radius: ?f32 = null,
    centralAngle: ?f32 = null,
    aspectRatio: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "radius", "centralAngle", "aspectRatio" };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"transform"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "transform", "XRRigidTransform" },
    };
};
