//! WebIDL dictionary: ImageEncodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageEncodeOptions = struct {
    type: ?runtime.DOMString = null,
    quality: ?f64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "image/png" } },
    };
};
