//! CSS Tables 3 §3.5.2.1: two nonnegative spacing lengths, without layout.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const Corner = @import("border_radius.zig").Corner;

/// Parse one or two lengths. The existing immutable two-axis value owns,
/// computes and serializes these scalars just as it does corner radii;
/// percentages are excluded by this property's grammar before storage.
pub fn consumeSpacing(options: properties.ParseOptions, stream: *properties.Stream) std.mem.Allocator.Error!?values.Value {
    // Tables3 §3.5.2.1: first horizontal, then vertical; an omitted second
    // length copies the first. Values4 range checks clamp outer math only.
    const flags: properties.LengthFlags = .{ .negative = false, .percent = false, .quirky = false };
    const horizontal = try properties.lengthPercentage(options, stream, flags) orelse return null;
    defer horizontal.release();
    const vertical = try properties.lengthPercentage(options, stream, flags);
    defer if (vertical) |owned| owned.release();
    return .{ .corner_radius = try Corner.create(options.allocator, horizontal, vertical orelse horizontal) };
}
