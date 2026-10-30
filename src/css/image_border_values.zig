//! CSS Backgrounds 3 §5.7 / CSS Masking §8.7: shared outer image-border grammar.
//! Q173 extracts only mask_values.parseBorder; the component owners are unchanged.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const quads = @import("image_quad.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

/// `longhands` is ordered source, slice, width, outset, repeat. Component
/// parsing stays with each property's existing owner. Design reference:
/// Blink css_parsing_utils::ConsumeBorderImageComponents (not copied).
pub fn parse(comptime longhands: [5]properties.Longhand, options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // 1. Backgrounds §5.7: omitted components take their initial values.
    // Preserve Q173's retained-default and replacement ownership order.
    var components: [longhands.len]Value = undefined;
    for (longhands, &components) |l, *v| {
        v.* = l.info().initial;
        v.retain();
    }
    defer for (components) |v| v.release();
    var seen = @as([longhands.len]bool, @splat(false));
    var groups: usize = 0;
    while (!stream.atEnd()) {
        var matched = false;
        // 2. Source, slice group and repeat group are unordered, each once.
        // Failed alternatives restore the entire stream, including lookahead.
        for ([_]usize{ 0, 1, 4 }) |i| {
            if (seen[i]) continue;
            const mark = stream.*;
            const value = (try properties.parseLonghand(options, longhands[i], stream)) orelse {
                stream.* = mark;
                continue;
            };
            components[i].release();
            components[i] = value;
            seen[i] = true;
            groups += 1;
            matched = true;
            // 3. Only the slice group owns width/outset slash productions.
            if (i == 1 and slash(stream)) {
                const width_mark = stream.*;
                const width = try quads.parse(options, stream, .width);
                if (width) |v| {
                    components[2].release();
                    components[2] = v;
                } else stream.* = width_mark;
                if (slash(stream)) {
                    const outset = (try quads.parse(options, stream, .outset)) orelse return false;
                    components[3].release();
                    components[3] = outset;
                } else if (width == null) {
                    // Q52's accepted mask behavior and Blink's image-border
                    // parser reject a slash with neither width nor outset.
                    return false;
                }
            }
            break;
        }
        if (!matched) return false;
    }
    if (groups == 0) return false;
    // 4. Reserve before transferring, preserving source/slice/width/outset/
    // repeat order. Every rejection/OOM releases all temporary components.
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, components) |l, v| {
        v.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    return true;
}

fn slash(stream: *properties.Stream) bool {
    const t = stream.peek();
    if (t.token_type != .delim or !std.mem.eql(u8, t.value, "/")) return false;
    _ = stream.next();
    return true;
}
