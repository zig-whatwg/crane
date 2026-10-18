//! WebIDL dictionary: XRWebGLLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRWebGLLayerInit = struct {
    antialias: ?bool = null,
    depth: ?bool = null,
    stencil: ?bool = null,
    alpha: ?bool = null,
    ignoreDepthValues: ?bool = null,
    framebufferScaleFactor: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"framebufferScaleFactor"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "antialias", .{ .boolean = true } },
        .{ "depth", .{ .boolean = true } },
        .{ "stencil", .{ .boolean = false } },
        .{ "alpha", .{ .boolean = true } },
        .{ "ignoreDepthValues", .{ .boolean = false } },
        .{ "framebufferScaleFactor", .{ .number = 1 } },
    };
};
