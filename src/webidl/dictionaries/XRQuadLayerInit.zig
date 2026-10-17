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

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"transform"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "transform", "XRRigidTransform" },
    };
};
