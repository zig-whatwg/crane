//! WebIDL dictionary: ImageBitmapRenderingContextSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageBitmapRenderingContextSettings = struct {
    alpha: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "alpha", .{ .boolean = true } },
    };
};
