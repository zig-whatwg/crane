//! WebIDL dictionary: XRLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRLayerInit = struct {
    space: *runtime.Instance,
    textureType: ?enums.XRTextureType = null,
    colorFormat: ?typedefs.GLenum = null,
    depthFormat: ?typedefs.GLenum = null,
    mipLevels: ?u32 = null,
    viewPixelWidth: u32,
    viewPixelHeight: u32,
    layout: ?enums.XRLayerLayout = null,
    isStatic: ?bool = null,
    clearOnAccess: ?bool = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"depthFormat"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "space", "XRSpace" },
    };
};
