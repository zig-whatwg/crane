//! CSS Fonts4 §2.7: font grammar, pending system fonts and all reset-only arms.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const widths = @import("font_width.zig");
const styles = @import("font_style.zig");
const system = @import("font_system.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Longhand = properties.Longhand;

pub const longhands = [_]Longhand{
    .font_style,            .font_variant_caps,      .font_weight,            .font_width,            .font_size,               .line_height,             .font_family,
    .font_feature_settings, .font_kerning,           .font_language_override, .font_optical_sizing,   .font_size_adjust,        .font_variant_alternates, .font_variant_east_asian,
    .font_variant_emoji,    .font_variant_ligatures, .font_variant_numeric,   .font_variant_position, .font_variation_settings,
};
const explicit_count = 7;

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    if (system.Keyword.parse(stream)) |keyword| {
        if (!stream.atEnd()) return false;
        // Q28's Chrome mechanism: every longhand remains pending, and no
        // optional host fallback is made into specified CSSOM data.
        try out.ensureUnusedCapacity(options.allocator, longhands.len);
        for (longhands) |l| out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = .{ .font_system = keyword } } });
        return true;
    }
    var parsed: [explicit_count]Value = undefined;
    for (longhands[0..explicit_count], 0..) |l, i| {
        parsed[i] = l.info().initial;
        parsed[i].retain();
    }
    // The font shorthand's omitted weight is the specified keyword normal;
    // the existing longhand table stores its equivalent computed 400.
    parsed[2] = Value.kw(.normal);
    defer for (parsed) |v| v.release();
    var seen = @as([4]bool, @splat(false));
    var prefix_count: usize = 0;
    while (true) {
        if (take(stream, "normal")) {
            prefix_count += 1;
            if (prefix_count > 4) return false;
            continue;
        }
        var found = false;
        for (0..4) |i| {
            if (seen[i]) continue;
            const mark = stream.*;
            const next: ?Value = switch (i) {
                0 => try styles.parse(options, stream),
                1 => if (take(stream, "small-caps")) Value{ .text = try values.SharedText.create(options.allocator, "small-caps") } else null,
                2 => try properties.parseLonghand(options, .font_weight, stream),
                3 => if (widths.Keyword.parse(stream)) |k| Value{ .font_width_keyword = k } else null,
                else => unreachable,
            };
            if (next) |v| {
                parsed[i].release();
                parsed[i] = v;
                seen[i] = true;
                prefix_count += 1;
                if (prefix_count > 4) return false;
                found = true;
                break;
            }
            stream.* = mark;
        }
        if (!found) break;
    }
    // §2.7 requires both size and family, with an optional slash line-height.
    const size = (try properties.parseLonghand(options, .font_size, stream)) orelse return false;
    parsed[4].release();
    parsed[4] = size;
    const token = stream.peek();
    if (token.token_type == .delim and std.mem.eql(u8, token.value, "/")) {
        _ = stream.next();
        const height = (try properties.parseLonghand(options, .line_height, stream)) orelse return false;
        parsed[5].release();
        parsed[5] = height;
    }
    const family = (try properties.parseLonghand(options, .font_family, stream)) orelse return false;
    parsed[6].release();
    parsed[6] = family;
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, 0..) |l, i| {
        const v = if (i < explicit_count) parsed[i] else l.info().initial;
        v.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    return true;
}

/// CSSOM §6.7.2: all reset-only values must be initial, and system tokens
/// must agree on every longhand. Blink FontValue follows this same design.
pub fn serialize(vs: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    if (vs[0].value == .font_system) {
        const system_value = vs[0].value;
        for (vs[1..]) |v| if (!v.value.eql(system_value)) return false;
        try out.appendSlice(allocator, system_value.font_system.name());
        return true;
    }
    for (vs) |v| if (v.value == .font_system) return false;
    for (vs[explicit_count..], longhands[explicit_count..]) |v, l| if (!v.value.eql(l.info().initial)) return false;
    const caps = vs[1].value;
    if (!normal(caps) and !(caps == .text and std.mem.eql(u8, caps.text.bytes, "small-caps"))) return false;
    const width = widths.shorthandKeyword(vs[3].value) orelse return false;
    const start = out.items.len;
    for (0..3) |i| {
        const v = vs[i].value;
        if (normal(v)) continue;
        if (i == 2 and mode == .computed and v == .number and v.number == 400) continue;
        if (out.items.len != start) try out.append(allocator, ' ');
        try properties.serializeValue(longhands[i], v, out, allocator);
    }
    if (width != .normal) {
        if (out.items.len != start) try out.append(allocator, ' ');
        try out.appendSlice(allocator, width.name());
    }
    if (out.items.len != start) try out.append(allocator, ' ');
    try properties.serializeValue(.font_size, vs[4].value, out, allocator);
    if (!normal(vs[5].value)) {
        try out.appendSlice(allocator, " / ");
        // getComputedStyle(font) uses line-height's resolved px value too.
        if (mode == .computed and vs[5].value == .number and vs[4].value == .length) {
            try values.appendLength(.px(vs[5].value.number * vs[4].value.length.value), out, allocator);
        } else try properties.serializeValue(.line_height, vs[5].value, out, allocator);
    }
    try out.append(allocator, ' ');
    try properties.serializeValue(.font_family, vs[6].value, out, allocator);
    return true;
}

fn normal(v: Value) bool {
    return v == .keyword and v.keyword == .normal;
}
fn take(stream: *properties.Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokens.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}
