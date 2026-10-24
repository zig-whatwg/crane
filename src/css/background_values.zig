//! CSS Backgrounds3 §§2–3 / Backgrounds4 §§2.6–2.12: typed layers.
//! The image count controls used layers; computed lists retain their lengths.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const layers = @import("image_layers.zig");
const positions = @import("position_values.zig");
const sizes = @import("image_size.zig");
const keywords = @import("image_keywords.zig");
const parts = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Longhand = properties.Longhand;
const Keyword = keywords.Keyword;

pub const longhands = [_]Longhand{
    .background_image,  .background_position_x, .background_position_y,
    .background_size,   .background_repeat,     .background_attachment,
    .background_origin, .background_clip,       .background_color,
};
pub const position_longhands = [_]Longhand{ .background_position_x, .background_position_y };
const Layer = [9]Value;
const Parsed = struct { layer: Layer, color: bool };
const boxes = [_]Keyword{ .border_box, .padding_box, .content_box };

pub fn parse(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    var strict = options;
    strict.quirks = false;
    return layers.parse(strict, longhand, stream, parseComponent);
}

fn parseComponent(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .background_image => properties.parseLonghand(options, .list_style_image, stream),
        .background_position_x, .background_position_y => positions.parseAxis(options, stream, longhand == .background_position_x),
        .background_size => sizes.parse(options, stream),
        .background_repeat => if (keywords.Repeat.parse(stream, false)) |r| .{ .image_repeat = r } else null,
        .background_attachment => if (Keyword.parse(stream, &.{ .scroll, .fixed, .local })) |k| .{ .image_keyword = k } else null,
        .background_origin => if (Keyword.parse(stream, &boxes)) |k| .{ .image_keyword = k } else null,
        .background_clip => parseClip(stream),
        .background_color => properties.parseLonghand(options, .background_color, stream),
        else => unreachable,
    };
}

/// Backgrounds4 §2.8: a visual box, or border-area || text. The latter
/// union has no geometry here; it is one typed scalar with canonical order.
fn parseClip(stream: *properties.Stream) ?Value {
    if (Keyword.parse(stream, &boxes)) |box| return .{ .image_keyword = box };
    const first = Keyword.parse(stream, &.{ .border_area, .text }) orelse return null;
    const other: Keyword = if (first == .text) .border_area else .text;
    if (Keyword.parse(stream, &.{other}) != null) return .{ .image_keyword = .border_area_text };
    return .{ .image_keyword = first };
}

pub fn parseShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var strict = options;
    strict.quirks = false;
    var parsed: std.ArrayList(Layer) = .empty;
    defer {
        for (parsed.items) |layer| for (layer) |v| v.release();
        parsed.deinit(options.allocator);
    }
    while (true) {
        const result = (try parseLayer(strict, stream)) orelse return false;
        errdefer for (result.layer) |v| v.release();
        try parsed.append(options.allocator, result.layer);
        if (stream.peek().token_type != .comma) break;
        // §2.12: only the final background layer can carry the base color.
        if (result.color) return false;
        _ = stream.next();
    }
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    const column = try options.allocator.alloc(Value, parsed.items.len);
    defer options.allocator.free(column);
    for (longhands[0..8], 0..) |l, i| {
        for (parsed.items, 0..) |layer, j| column[j] = layer[i];
        const v = try makeList(options.allocator, l, column);
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    const color = parsed.items[parsed.items.len - 1][8];
    color.retain();
    out.appendAssumeCapacity(.{ .longhand = .background_color, .value = .{ .value = color } });
    return true;
}

fn makeList(allocator: Allocator, longhand: Longhand, items: []const Value) Allocator.Error!Value {
    if (items.len == 1) {
        items[0].retain();
        return items[0];
    }
    return .{ .layers = try layers.Layers.create(allocator, longhand, items) };
}

fn parseLayer(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Parsed {
    var result: Layer = undefined;
    for (longhands, 0..) |l, i| {
        result[i] = l.info().initial;
        result[i].retain();
    }
    var moved = false;
    defer if (!moved) for (result) |v| v.release();
    var seen = [_]bool{false} ** 9;
    var components: usize = 0;
    var box_count: u2 = 0;
    var clip_only = false;
    while (!stream.atEnd() and stream.peek().token_type != .comma) {
        // §2.12: one visual box fills both roles. Q80 case4: bare text
        // keeps padding-box origin (Chrome/Safari computed; Firefox/Safari
        // specified). Q109 case5 keeps border-box for border-area || text.
        if (!clip_only and box_count < 2) {
            const mark = stream.*;
            if (parseClip(stream)) |clip| {
                const special = clip.image_keyword == .text or clip.image_keyword == .border_area or clip.image_keyword == .border_area_text;
                if (special) {
                    result[7].release();
                    result[7] = clip;
                    if (box_count == 0) {
                        result[6].release();
                        result[6] = .{ .image_keyword = if (clip.image_keyword == .text) .padding_box else .border_box };
                    }
                    clip_only = true;
                    components += 1;
                    continue;
                }
            }
            stream.* = mark;
        }
        if (box_count < (if (clip_only) @as(u2, 1) else 2)) if (Keyword.parse(stream, &boxes)) |box| {
            const index: usize = if (box_count == 0) 6 else 7;
            result[index].release();
            result[index] = .{ .image_keyword = box };
            if (box_count == 0 and !clip_only) {
                result[7].release();
                result[7] = .{ .image_keyword = box };
            }
            box_count += 1;
            components += 1;
            continue;
        };
        var found = false;
        for ([_]usize{ 0, 1, 4, 5, 8 }) |index| {
            if (seen[index]) continue;
            const mark = stream.*;
            if (index == 1) {
                const position = (try positions.parse(options, stream, .background)) orelse {
                    stream.* = mark;
                    continue;
                };
                defer position.unref();
                // Q47: physical x/y and x/y-relative edges are granted.
                // Block/inline expansion awaits a shipping/spec mapping.
                if (position.logical) return null;
                for (position.data.specified, 0..) |anchor, axis| {
                    const v: Value = .{ .image_axis = try positions.PositionAxis.create(options.allocator, anchor) };
                    result[1 + axis].release();
                    result[1 + axis] = v;
                }
                if (slash(stream)) {
                    const size = (try sizes.parse(options, stream)) orelse return null;
                    result[3].release();
                    result[3] = size;
                }
            } else {
                const v = (try parseComponent(options, longhands[index], stream)) orelse {
                    stream.* = mark;
                    continue;
                };
                result[index].release();
                result[index] = v;
            }
            seen[index] = true;
            found = true;
            components += 1;
            break;
        }
        if (!found) return null;
    }
    if (components == 0) return null;
    moved = true;
    return .{ .layer = result, .color = seen[8] };
}

fn slash(stream: *properties.Stream) bool {
    const token = stream.peek();
    if (token.token_type != .delim or !std.mem.eql(u8, token.value, "/")) return false;
    _ = stream.next();
    return true;
}

/// §2.7: parse the pair once, then own each independent component. No
/// computed writing-mode mapping is performed while parsing the declaration.
pub fn parsePosition(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var strict = options;
    strict.quirks = false;
    var xs: std.ArrayList(Value) = .empty;
    defer {
        for (xs.items) |v| v.release();
        xs.deinit(options.allocator);
    }
    var ys: std.ArrayList(Value) = .empty;
    defer {
        for (ys.items) |v| v.release();
        ys.deinit(options.allocator);
    }
    while (true) {
        const position = (try positions.parse(strict, stream, .background)) orelse return false;
        defer position.unref();
        if (position.logical) return false;
        {
            const x: Value = .{ .image_axis = try positions.PositionAxis.create(options.allocator, position.data.specified[0]) };
            errdefer x.release();
            try xs.append(options.allocator, x);
        }
        {
            const y: Value = .{ .image_axis = try positions.PositionAxis.create(options.allocator, position.data.specified[1]) };
            errdefer y.release();
            try ys.append(options.allocator, y);
        }
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, 2);
    const x = try makeList(options.allocator, .background_position_x, xs.items);
    out.appendAssumeCapacity(.{ .longhand = .background_position_x, .value = .{ .value = x } });
    const y = try makeList(options.allocator, .background_position_y, ys.items);
    out.appendAssumeCapacity(.{ .longhand = .background_position_y, .value = .{ .value = y } });
    return true;
}

pub fn serializePosition(vs: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == 2);
    const count = layers.count(vs[0].value);
    if (count != layers.count(vs[1].value)) return false;
    for (0..count) |i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        try positions.serializeAxes(layers.at(vs[0].value, i), layers.at(vs[1].value, i), out, allocator);
    }
    return true;
}

/// CSSOM §6.7.2 / Values4 Appendix A: only initial-valued singleton lists
/// can be omitted; other component lists must agree in their authored count.
pub fn serialize(vs: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    var length: ?usize = null;
    var initial = [_]bool{false} ** 8;
    for (longhands[0..8], vs[0..8], 0..) |l, assigned, i| {
        initial[i] = layers.count(assigned.value) == 1 and try isInitial(l, assigned.value, allocator);
        if (initial[i]) continue;
        if (length) |n| {
            if (layers.count(assigned.value) != n) return false;
        } else length = layers.count(assigned.value);
    }
    const count = length orelse 1;
    for (0..count) |i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        var layer: Layer = undefined;
        for (vs[0..8], 0..) |assigned, j| layer[j] = layers.at(assigned.value, if (initial[j]) 0 else i);
        layer[8] = if (i + 1 == count) vs[8].value else Longhand.background_color.info().initial;
        try serializeLayer(layer, out, allocator);
    }
    return true;
}

/// Q80 cases0-3/6: Chrome155/Safari27 use this full computed order;
/// Firefox's minimal form is outvoted (integrator-probes-1023s/1023q).
/// Case4's text origin follows Chrome/Safari, with Firefox/Safari's specified
/// spelling handled above. Q109 case5 preserves border-area text: Chrome156
/// passes the pinned tests; Safari27 dropping text is a defect.
pub fn serializeComputed(vs: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    // Q119 FINAL (q119-P1..P5/C6/C7): Chrome/Safari's mechanism matches
    // each column independently to image count, including excess entries.
    // This is CSSOM shorthand text; it never rewrites a stored longhand.
    const count = layers.count(vs[0].value);
    for (0..count) |i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        // Backgrounds3 §2.10: only the final layer carries the base color.
        if (i + 1 == count) {
            try properties.serializeValue(.background_color, vs[8].value, out, allocator);
            try out.append(allocator, ' ');
        }
        // URL resolution uses the same frozen metadata as longhand CSSOM.
        try @import("resolved_urls.zig").serialize(.background_image, layers.at(vs[0].value, i), out, allocator);
        for ([_]usize{ 4, 5 }) |column| {
            try out.append(allocator, ' ');
            try properties.serializeValue(longhands[column], layers.atUsed(vs[column].value, i), out, allocator);
        }
        try out.append(allocator, ' ');
        try positions.serializeAxes(layers.atUsed(vs[1].value, i), layers.atUsed(vs[2].value, i), out, allocator);
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.background_size, layers.atUsed(vs[3].value, i), out, allocator);
        for ([_]usize{ 6, 7 }) |column| {
            try out.append(allocator, ' ');
            try properties.serializeValue(longhands[column], layers.atUsed(vs[column].value, i), out, allocator);
        }
    }
    return true;
}

/// Q119/Q120: the resolved size longhand repeats a short list to image
/// count (Chrome/Firefox), but keeps longer lists (Firefox/Safari). C7's
/// Chrome/Safari majority pins the target to image count, not another list.
/// The immutable computed Values stay borrowed; only output may allocate.
pub fn serializeComputedSize(size: Value, image_count: usize, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const count = @max(image_count, layers.count(size));
    for (0..count) |i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        try properties.serializeValue(.background_size, layers.atUsed(size, i), out, allocator);
    }
}

fn serializeLayer(layer: Layer, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const start = out.items.len;
    var initial: [9]bool = undefined;
    for (longhands, layer, 0..) |l, v, i| initial[i] = try isInitial(l, v, allocator);
    if (!initial[0]) try componentText(0, layer[0], start, out, allocator);
    if (!initial[1] or !initial[2] or !initial[3]) {
        if (out.items.len != start) try out.append(allocator, ' ');
        try positions.serializeAxes(layer[1], layer[2], out, allocator);
        if (!initial[3]) {
            try out.appendSlice(allocator, " / ");
            try properties.serializeValue(.background_size, layer[3], out, allocator);
        }
    }
    if (!initial[4]) try componentText(4, layer[4], start, out, allocator);
    if (!initial[5]) try componentText(5, layer[5], start, out, allocator);
    if (!initial[6] or !initial[7]) {
        if (layer[6].eql(layer[7])) try componentText(6, layer[6], start, out, allocator) else {
            const clip_only = layer[7] == .image_keyword and (layer[7].image_keyword == .text or layer[7].image_keyword == .border_area or layer[7].image_keyword == .border_area_text);
            if (!clip_only or !(layer[6] == .image_keyword and layer[6].image_keyword == .border_box)) try componentText(6, layer[6], start, out, allocator);
            try componentText(7, layer[7], start, out, allocator);
        }
    }
    if (!initial[8]) try componentText(8, layer[8], start, out, allocator);
    if (out.items.len == start) try out.appendSlice(allocator, "none");
}
fn componentText(index: usize, v: Value, start: usize, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (out.items.len != start) try out.append(allocator, ' ');
    try properties.serializeValue(longhands[index], v, out, allocator);
}
fn isInitial(l: Longhand, v: Value, allocator: Allocator) Allocator.Error!bool {
    if (v.eql(l.info().initial)) return true;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try properties.serializeValue(l, v, &text, allocator);
    const expected: []const u8 = switch (l) {
        .background_image => "none",
        .background_position_x, .background_position_y => "0%",
        .background_size => "auto",
        .background_repeat => "repeat",
        .background_attachment => "scroll",
        .background_origin => "padding-box",
        .background_clip => "border-box",
        .background_color => "rgba(0, 0, 0, 0)",
        else => unreachable,
    };
    return std.mem.eql(u8, text.items, expected);
}
