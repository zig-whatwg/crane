//! CSS Backgrounds 3 §§5.1–5.7: border-image property adapters and serialization.
//! Component values, math, computation, URLs and currentcolor keep their owners.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const quads = @import("image_quad.zig");
const keywords = @import("image_keywords.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Longhand = properties.Longhand;

pub const longhands = [_]Longhand{
    .border_image_source,
    .border_image_slice,
    .border_image_width,
    .border_image_outset,
    .border_image_repeat,
};

/// Backgrounds §§5.1–5.5: reuse the existing strict typed component grammars.
pub fn parse(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .border_image_source => properties.parseLonghand(options, .list_style_image, stream),
        .border_image_slice => quads.parse(options, stream, .slice),
        .border_image_width => quads.parse(options, stream, .width),
        .border_image_outset => quads.parse(options, stream, .outset),
        .border_image_repeat => if (keywords.Repeat.parse(stream, true)) |v| .{ .image_repeat = v } else null,
        else => unreachable,
    };
}

pub fn parseShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    return @import("image_border_values.zig").parse(longhands, options, stream, out);
}

/// CSSOM §6.7.2, with Q174 PART2's complete browser mechanisms:
/// main/tmp/analysis/integrator-probes-1024c/results/q174-{chrome,firefox,safari}.json.
/// Specified shortest form is Firefox+Safari, with Firefox's required 100%
/// slice context where Safari incorrectly returns empty. Computed none hiding
/// and non-none full expansion follow Chrome+Safari. Design reference:
/// WebKit ShorthandSerializer::serializeBorderImage; no engine code copied.
pub fn serialize(vs: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    if (mode == .computed) {
        // 1. Q174: source none hides only the computed shorthand's components.
        if (vs[0].value.isKeyword(.none)) {
            try out.appendSlice(allocator, "none");
            return true;
        }
        // 2. Q174: otherwise include every component, using frozen URL data.
        // The receiver's existing computed reader resolves currentcolor first.
        for (longhands, vs, 0..) |l, v, i| {
            if (i != 0) try out.appendSlice(allocator, if (i == 2 or i == 3) " / " else " ");
            try @import("resolved_urls.zig").serialize(l, v.value, out, allocator);
        }
        return true;
    }
    // 3. CSSOM §6.7.2 step 2: omit initial components while preserving grammar.
    var initial: [longhands.len]bool = undefined;
    for (longhands, vs, &initial) |l, v, *flag| flag.* = isInitial(l, v.value);
    const include_slice = !initial[1] or !initial[2] or !initial[3];
    const start = out.items.len;
    if (!initial[0]) try properties.serializeValue(longhands[0], vs[0].value, out, allocator);
    if (include_slice) {
        if (out.items.len != start) try out.append(allocator, ' ');
        try properties.serializeValue(longhands[1], vs[1].value, out, allocator);
        if (!initial[2]) {
            try out.appendSlice(allocator, " / ");
            try properties.serializeValue(longhands[2], vs[2].value, out, allocator);
        }
        if (!initial[3]) {
            try out.appendSlice(allocator, if (initial[2]) " / / " else " / ");
            try properties.serializeValue(longhands[3], vs[3].value, out, allocator);
        }
    }
    if (!initial[4]) {
        if (out.items.len != start) try out.append(allocator, ' ');
        try properties.serializeValue(longhands[4], vs[4].value, out, allocator);
    }
    // 4. All initial values have the shortest representable form none.
    if (out.items.len == start) try out.appendSlice(allocator, "none");
    return true;
}

/// Narrow typed initial equivalence for this family and border's reset guard.
/// Metadata uses allocation-free scalars; parsing owns expanded four-side quads.
/// This does not serialize/reparse, evaluate math, or change mask's predicate.
pub fn isInitial(longhand: Longhand, value: Value) bool {
    const initial = longhand.info().initial;
    if (value.eql(initial)) return true;
    return switch (longhand) {
        .border_image_slice, .border_image_width, .border_image_outset => blk: {
            if (value != .image_quad or value.image_quad.fill) break :blk false;
            for (value.image_quad.sides) |side| if (!side.eql(initial)) break :blk false;
            break :blk true;
        },
        .border_image_source, .border_image_repeat => false,
        else => unreachable,
    };
}
