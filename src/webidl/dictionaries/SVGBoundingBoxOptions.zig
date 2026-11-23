//! WebIDL dictionary: SVGBoundingBoxOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SVGBoundingBoxOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    fill: ?bool = null,
    stroke: ?bool = null,
    markers: ?bool = null,
    clipped: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "fill", .{ .boolean = true } },
        .{ "stroke", .{ .boolean = false } },
        .{ "markers", .{ .boolean = false } },
        .{ "clipped", .{ .boolean = false } },
    };
};
