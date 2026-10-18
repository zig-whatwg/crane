//! WebIDL dictionary: FontFaceDescriptors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const FontFaceDescriptors = struct {
    style: ?typedefs.CSSOMString = null,
    weight: ?typedefs.CSSOMString = null,
    stretch: ?typedefs.CSSOMString = null,
    unicodeRange: ?typedefs.CSSOMString = null,
    featureSettings: ?typedefs.CSSOMString = null,
    variationSettings: ?typedefs.CSSOMString = null,
    display: ?typedefs.CSSOMString = null,
    ascentOverride: ?typedefs.CSSOMString = null,
    descentOverride: ?typedefs.CSSOMString = null,
    lineGapOverride: ?typedefs.CSSOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "style", .{ .string = "normal" } },
        .{ "weight", .{ .string = "normal" } },
        .{ "stretch", .{ .string = "normal" } },
        .{ "unicodeRange", .{ .string = "U+0-10FFFF" } },
        .{ "featureSettings", .{ .string = "normal" } },
        .{ "variationSettings", .{ .string = "normal" } },
        .{ "display", .{ .string = "auto" } },
        .{ "ascentOverride", .{ .string = "normal" } },
        .{ "descentOverride", .{ .string = "normal" } },
        .{ "lineGapOverride", .{ .string = "normal" } },
    };
};
