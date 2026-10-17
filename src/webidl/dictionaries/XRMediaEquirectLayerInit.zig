//! WebIDL dictionary: XRMediaEquirectLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRMediaLayerInit = @import("XRMediaLayerInit.zig").XRMediaLayerInit;

pub const XRMediaEquirectLayerInit = struct {
    // Inherited from XRMediaLayerInit
    base: XRMediaLayerInit,

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

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "transform", "XRRigidTransform" },
    };
};
