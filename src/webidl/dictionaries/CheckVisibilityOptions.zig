//! WebIDL dictionary: CheckVisibilityOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CheckVisibilityOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    checkOpacity: ?bool = null,
    checkVisibilityCSS: ?bool = null,
    contentVisibilityAuto: ?bool = null,
    opacityProperty: ?bool = null,
    visibilityProperty: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "checkOpacity", .{ .boolean = false } },
        .{ "checkVisibilityCSS", .{ .boolean = false } },
        .{ "contentVisibilityAuto", .{ .boolean = false } },
        .{ "opacityProperty", .{ .boolean = false } },
        .{ "visibilityProperty", .{ .boolean = false } },
    };
};
