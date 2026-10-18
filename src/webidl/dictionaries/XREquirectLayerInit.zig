//! WebIDL dictionary: XREquirectLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRLayerInit = @import("XRLayerInit.zig").XRLayerInit;

pub const XREquirectLayerInit = struct {
    // Inherited from XRLayerInit
    base: XRLayerInit,

    transform: ?*runtime.Instance = null,
    radius: ?f32 = null,
    centralHorizontalAngle: ?f32 = null,
    upperVerticalAngle: ?f32 = null,
    lowerVerticalAngle: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "radius", "centralHorizontalAngle", "upperVerticalAngle", "lowerVerticalAngle" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "radius", .{ .number = 0 } },
        .{ "centralHorizontalAngle", .{ .number = 6.28318 } },
        .{ "upperVerticalAngle", .{ .number = 1.570795 } },
        .{ "lowerVerticalAngle", .{ .number = -1.570795 } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"transform"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "transform", "XRRigidTransform" },
    };
};
