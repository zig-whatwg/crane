//! WebIDL dictionary: XRProjectionLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRProjectionLayerInit = struct {
    textureType: ?enums.XRTextureType = null,
    colorFormat: ?typedefs.GLenum = null,
    depthFormat: ?typedefs.GLenum = null,
    scaleFactor: ?f64 = null,
    clearOnAccess: ?bool = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"scaleFactor"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "textureType", .{ .string = "texture" } },
        .{ "colorFormat", .{ .number = 6408 } },
        .{ "depthFormat", .{ .number = 6402 } },
        .{ "scaleFactor", .{ .number = 1 } },
        .{ "clearOnAccess", .{ .boolean = true } },
    };
};
