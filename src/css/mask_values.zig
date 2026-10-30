//! CSS Masking §§7–8: mask layers, component lists, and shorthand resets.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const layers = @import("image_layers.zig");
const positions = @import("position_values.zig");
const sizes = @import("image_size.zig");
const quads = @import("image_quad.zig");
const keywords = @import("image_keywords.zig");
const parts = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Longhand = properties.Longhand;
const Keyword = keywords.Keyword;

pub const longhands = [_]Longhand{
    .mask_image,         .mask_position,     .mask_size,         .mask_repeat,
    .mask_origin,        .mask_clip,         .mask_composite,    .mask_mode,
    .mask_border_source, .mask_border_slice, .mask_border_width, .mask_border_outset,
    .mask_border_repeat,
};
const Layer = [8]Value;
const boxes = [_]Keyword{ .border_box, .padding_box, .content_box, .fill_box, .stroke_box, .view_box };

// Masking §8.7. Q50's browser probe: Safari ships these five; no browser
// ships mask-border-mode, so that component remains a spec follow-up.
pub const border_longhands = longhands[8..].*;

pub fn parseBorder(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    return @import("image_border_values.zig").parse(border_longhands, options, stream, out);
}

/// CSSOM shorthand serialization, with Q52's Safari mechanism pinned by
/// integrator-probes-1023g/results/q89q52-*.json. Design reference:
/// WebKit ShorthandSerializer::serializeMaskBorder (no code copied).
pub fn serializeBorder(vs: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == border_longhands.len);
    if (mode == .computed) {
        // A none source hides the other computed shorthand components;
        // longhand reads retain their own computed values.
        if (vs[0].value.isKeyword(.none)) {
            try out.appendSlice(allocator, "none");
            return true;
        }
        for (border_longhands, vs, 0..) |l, v, i| {
            if (i != 0) try out.appendSlice(allocator, if (i == 2 or i == 3) " / " else " ");
            try @import("resolved_urls.zig").serialize(l, v.value, out, allocator);
        }
        return true;
    }
    var initial: [border_longhands.len]bool = undefined;
    for (border_longhands, vs, &initial) |l, v, *flag| flag.* = try isInitial(l, v.value, allocator);
    // Q52: Safari's specified serialization is empty for an initial slice
    // with a noninitial width/outset. Keep this spec discrepancy explicit.
    if (initial[1] and (!initial[2] or !initial[3])) return false;
    const start = out.items.len;
    for (border_longhands, vs, initial, 0..) |l, v, omit, i| {
        if (omit) continue;
        if (i == 2) {
            try out.appendSlice(allocator, " / ");
        } else if (i == 3) {
            try out.appendSlice(allocator, if (initial[2]) " / / " else " / ");
        } else if (out.items.len != start) try out.append(allocator, ' ');
        try properties.serializeValue(l, v.value, out, allocator);
    }
    if (out.items.len == start) try out.appendSlice(allocator, "none");
    return true;
}

pub fn parse(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .mask_border_source => properties.parseLonghand(options, .list_style_image, stream),
        .mask_border_slice => quads.parse(options, stream, .slice),
        .mask_border_width => quads.parse(options, stream, .width),
        .mask_border_outset => quads.parse(options, stream, .outset),
        .mask_border_repeat => if (keywords.Repeat.parse(stream, true)) |v| .{ .image_repeat = v } else null,
        .mask_type => if (Keyword.parse(stream, &.{ .alpha, .luminance })) |k| .{ .image_keyword = k } else null,
        else => layers.parse(options, longhand, stream, parseComponent),
    };
}

fn parseComponent(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .mask_image => properties.parseLonghand(options, .list_style_image, stream),
        .mask_position => if (try positions.parse(options, stream, .position)) |p| .{ .image_position = p } else null,
        .mask_size => sizes.parse(options, stream),
        .mask_repeat => if (keywords.Repeat.parse(stream, false)) |r| .{ .image_repeat = r } else null,
        .mask_origin => if (Keyword.parse(stream, &boxes)) |k| .{ .image_keyword = k } else null,
        .mask_clip => if (Keyword.parse(stream, &.{ .border_box, .padding_box, .content_box, .fill_box, .stroke_box, .view_box, .no_clip })) |k| .{ .image_keyword = k } else null,
        .mask_composite => if (Keyword.parse(stream, &.{ .add, .subtract, .intersect, .exclude })) |k| .{ .image_keyword = k } else null,
        .mask_mode => if (Keyword.parse(stream, &.{ .alpha, .luminance, .match_source })) |k| .{ .image_keyword = k } else null,
        else => unreachable,
    };
}

pub fn parseShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var parsed: std.ArrayList(Layer) = .empty;
    defer {
        for (parsed.items) |layer| for (layer) |v| v.release();
        parsed.deinit(options.allocator);
    }
    while (true) {
        const layer = (try parseLayer(options, stream)) orelse return false;
        errdefer for (layer) |v| v.release();
        try parsed.append(options.allocator, layer);
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    const column = try options.allocator.alloc(Value, parsed.items.len);
    defer options.allocator.free(column);
    for (longhands[0..8], 0..) |l, i| {
        for (parsed.items, 0..) |layer, j| column[j] = layer[i];
        const v: Value = if (column.len == 1) blk: {
            column[0].retain();
            break :blk column[0];
        } else .{ .layers = try layers.Layers.create(options.allocator, l, column) };
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    // Masking §7.9: mask resets every mask-border longhand, even though
    // none appears in mask's grammar. Reset values have one entry.
    for (longhands[8..]) |l| {
        const initial = l.info().initial;
        initial.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = initial } });
    }
    return true;
}

fn parseLayer(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Layer {
    var result: Layer = undefined;
    for (longhands[0..8], 0..) |l, i| {
        result[i] = l.info().initial;
        result[i].retain();
    }
    var moved = false;
    defer if (!moved) for (result) |v| v.release();
    var seen = @as([8]bool, @splat(false));
    var components: usize = 0;
    var box_count: u2 = 0;
    var no_clip = false;
    while (!stream.atEnd() and stream.peek().token_type != .comma) {
        if (!no_clip and box_count < 2 and parts.keyword(stream, "no-clip")) {
            result[5].release();
            result[5] = .{ .image_keyword = .no_clip };
            no_clip = true;
            components += 1;
            continue;
        }
        if (box_count < (if (no_clip) @as(u2, 1) else 2)) if (Keyword.parse(stream, &boxes)) |box| {
            const i: usize = if (box_count == 0) 4 else 5;
            result[i].release();
            result[i] = .{ .image_keyword = box };
            if (box_count == 0 and !no_clip) {
                result[5].release();
                result[5] = .{ .image_keyword = box };
            }
            box_count += 1;
            components += 1;
            continue;
        };
        var found = false;
        for ([_]usize{ 0, 1, 3, 6, 7 }) |i| {
            if (seen[i]) continue;
            const mark = stream.*;
            const v = (try parseComponent(options, longhands[i], stream)) orelse {
                stream.* = mark;
                continue;
            };
            result[i].release();
            result[i] = v;
            seen[i] = true;
            found = true;
            components += 1;
            if (i == 1 and slash(stream)) {
                const size = (try sizes.parse(options, stream)) orelse return null;
                result[2].release();
                result[2] = size;
            }
            break;
        }
        if (!found) return null;
    }
    if (components == 0) return null;
    moved = true;
    return result;
}

fn slash(stream: *properties.Stream) bool {
    const t = stream.peek();
    if (t.token_type != .delim or !std.mem.eql(u8, t.value, "/")) return false;
    _ = stream.next();
    return true;
}

/// CSSOM shorthand serialization plus Values4 Appendix A's coordinated
/// lists. Initial-valued longhands can be omitted; noninitial lists must
/// have the same length. No repetition/truncation changes computed values.
pub fn serialize(vs: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    for (longhands[8..], vs[8..]) |l, v| if (!try isInitial(l, v.value, allocator)) return false;
    var length: ?usize = null;
    var initial = @as([8]bool, @splat(false));
    for (longhands[0..8], vs[0..8], 0..) |l, assigned, i| {
        const v = assigned.value;
        initial[i] = layers.count(v) == 1 and try isInitial(l, v, allocator);
        if (initial[i]) continue;
        if (length) |n| {
            if (layers.count(v) != n) return false;
        } else length = layers.count(v);
    }
    const count = length orelse 1;
    for (0..count) |i| {
        if (i > 0) try out.appendSlice(allocator, ", ");
        var layer: Layer = undefined;
        for (vs[0..8], 0..) |assigned, j| layer[j] = layers.at(assigned.value, if (initial[j]) 0 else i);
        try serializeLayer(layer, mode, out, allocator);
    }
    return true;
}

fn serializeLayer(layer: Layer, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const start = out.items.len;
    var initial: [8]bool = undefined;
    for (longhands[0..8], layer, 0..) |l, v, i| initial[i] = try isInitial(l, v, allocator);
    if (!initial[0]) try componentText(0, layer[0], start, mode, out, allocator);
    if (!initial[1] or !initial[2]) {
        try componentText(1, layer[1], start, mode, out, allocator);
        if (!initial[2]) {
            try out.appendSlice(allocator, " / ");
            try properties.serializeValue(.mask_size, layer[2], out, allocator);
        }
    }
    if (!initial[3]) try componentText(3, layer[3], start, mode, out, allocator);
    if (!initial[4] or !initial[5]) {
        if (layer[4].eql(layer[5])) try componentText(4, layer[4], start, mode, out, allocator) else {
            // A lone no-clip leaves mask-origin at border-box.
            if (!initial[4] or !(layer[5] == .image_keyword and layer[5].image_keyword == .no_clip)) try componentText(4, layer[4], start, mode, out, allocator);
            try componentText(5, layer[5], start, mode, out, allocator);
        }
    }
    if (!initial[6]) try componentText(6, layer[6], start, mode, out, allocator);
    if (!initial[7]) try componentText(7, layer[7], start, mode, out, allocator);
    if (out.items.len == start) try out.appendSlice(allocator, "none");
}
fn componentText(index: usize, v: Value, start: usize, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (out.items.len > start) try out.append(allocator, ' ');
    if (mode == .computed) {
        try @import("resolved_urls.zig").serialize(longhands[index], v, out, allocator);
    } else try properties.serializeValue(longhands[index], v, out, allocator);
}
fn isInitial(l: Longhand, v: Value, allocator: Allocator) Allocator.Error!bool {
    if (v.eql(l.info().initial)) return true;
    // Parsed sizes/positions/quads own typed data; initial values use scalar
    // sentinels to avoid allocating when cascading an untouched property.
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try properties.serializeValue(l, v, &text, allocator);
    const expected: []const u8 = switch (l) {
        .mask_image, .mask_border_source => "none",
        .mask_position => "0% 0%",
        .mask_size, .mask_border_width => "auto",
        .mask_repeat => "repeat",
        .mask_origin, .mask_clip => "border-box",
        .mask_composite => "add",
        .mask_mode => "match-source",
        .mask_border_slice, .mask_border_outset => "0",
        .mask_border_repeat => "stretch",
        else => unreachable,
    };
    return std.mem.eql(u8, text.items, expected);
}
