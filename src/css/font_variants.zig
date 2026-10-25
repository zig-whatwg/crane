//! CSS Fonts4 §§6.4–6.11, 9.3: variant grammars and complete shorthand.
//! These values compute as specified; canonical text owns decoded names.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const serial = @import("serialize.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Longhand = properties.Longhand;

pub const Group = enum { ligatures, caps, alternates, numeric, east_asian, position, emoji };
pub const longhands = [_]Longhand{
    .font_variant_ligatures, .font_variant_caps,       .font_variant_alternates,
    .font_variant_numeric,   .font_variant_east_asian, .font_variant_position,
    .font_variant_emoji,
};
const Slot = enum {
    common,
    discretionary,
    historical,
    contextual,
    caps,
    stylistic,
    historical_forms,
    styleset,
    character_variant,
    swash,
    ornaments,
    annotation,
    figure,
    spacing,
    fraction,
    ordinal,
    slashed_zero,
    east_variant,
    east_width,
    ruby,
    position,
    emoji,

    fn group(self: Slot) Group {
        return switch (self) {
            .common, .discretionary, .historical, .contextual => .ligatures,
            .caps => .caps,
            .stylistic, .historical_forms, .styleset, .character_variant, .swash, .ornaments, .annotation => .alternates,
            .figure, .spacing, .fraction, .ordinal, .slashed_zero => .numeric,
            .east_variant, .east_width, .ruby => .east_asian,
            .position => .position,
            .emoji => .emoji,
        };
    }
    fn functionName(self: Slot) ?[]const u8 {
        return switch (self) {
            .stylistic => "stylistic",
            .styleset => "styleset",
            .character_variant => "character-variant",
            .swash => "swash",
            .ornaments => "ornaments",
            .annotation => "annotation",
            else => null,
        };
    }
    fn names(self: Slot) []const []const u8 {
        return switch (self) {
            .common => &.{ "common-ligatures", "no-common-ligatures" },
            .discretionary => &.{ "discretionary-ligatures", "no-discretionary-ligatures" },
            .historical => &.{ "historical-ligatures", "no-historical-ligatures" },
            .contextual => &.{ "contextual", "no-contextual" },
            .caps => &.{ "small-caps", "all-small-caps", "petite-caps", "all-petite-caps", "unicase", "titling-caps" },
            .historical_forms => &.{"historical-forms"},
            .figure => &.{ "lining-nums", "oldstyle-nums" },
            .spacing => &.{ "proportional-nums", "tabular-nums" },
            .fraction => &.{ "diagonal-fractions", "stacked-fractions" },
            .ordinal => &.{"ordinal"},
            .slashed_zero => &.{"slashed-zero"},
            .east_variant => &.{ "jis78", "jis83", "jis90", "jis04", "simplified", "traditional" },
            .east_width => &.{ "full-width", "proportional-width" },
            .ruby => &.{"ruby"},
            .position => &.{ "sub", "super" },
            .emoji => &.{ "text", "emoji", "unicode" },
            else => &.{},
        };
    }
};
const slot_count = @typeInfo(Slot).@"enum".fields.len;
const Piece = struct { text: []const u8, owned: ?[]u8 = null };
const Components = struct {
    pieces: [slot_count]?Piece = .{null} ** slot_count,
    normal: bool = false,
    none: bool = false,

    fn deinit(self: *Components, allocator: Allocator) void {
        for (self.pieces) |piece| if (piece) |p| if (p.owned) |owned| allocator.free(owned);
    }
    fn value(self: *const Components, allocator: Allocator, group: Group) Allocator.Error!Value {
        if (self.none and group == .ligatures) return Value.kw(.none);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        for (self.pieces, 0..) |piece, i| {
            const slot: Slot = @enumFromInt(i);
            if (slot.group() != group) continue;
            if (piece) |p| {
                if (out.items.len != 0) try out.append(allocator, ' ');
                try out.appendSlice(allocator, p.text);
            }
        }
        return if (out.items.len == 0) Value.kw(.normal) else .{ .text = try values.SharedText.create(allocator, out.items) };
    }
};

pub fn groupOf(longhand: Longhand) ?Group {
    for (longhands, 0..) |l, i| if (l == longhand) return @enumFromInt(i);
    return null;
}

pub fn parse(options: properties.ParseOptions, longhand: Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    const group = groupOf(longhand) orelse unreachable;
    var components = (try parseComponents(options.allocator, stream, group)) orelse return null;
    defer components.deinit(options.allocator);
    return try components.value(options.allocator, group);
}

fn parseComponents(allocator: Allocator, stream: *properties.Stream, only: ?Group) Allocator.Error!?Components {
    var result = Components{};
    var moved = false;
    defer if (!moved) result.deinit(allocator);
    if (take(stream, "normal")) {
        result.normal = true;
        return result;
    }
    if ((only == null or only.? == .ligatures) and take(stream, "none")) {
        result.none = true;
        return result;
    }
    var count: usize = 0;
    while (true) {
        const token = stream.peek();
        var found: ?struct { slot: Slot, name: []const u8, function: bool } = null;
        for (0..slot_count) |i| {
            const slot: Slot = @enumFromInt(i);
            if (only) |group| if (slot.group() != group) continue;
            if (token.token_type == .ident) {
                for (slot.names()) |name| if (tokens.nameEql(token.value, name)) {
                    found = .{ .slot = slot, .name = name, .function = false };
                    break;
                };
            } else if (token.token_type == .function) if (slot.functionName()) |name| {
                if (tokens.nameEql(token.value, name)) found = .{ .slot = slot, .name = name, .function = true };
            };
            if (found != null) break;
        }
        const item = found orelse break;
        const index = @intFromEnum(item.slot);
        if (result.pieces[index] != null) return null;
        _ = stream.next();
        if (item.function) {
            const text = (try parseFunction(allocator, stream, item.slot, item.name)) orelse return null;
            result.pieces[index] = .{ .text = text, .owned = text };
        } else result.pieces[index] = .{ .text = item.name };
        count += 1;
    }
    if (count == 0) return null;
    moved = true;
    return result;
}

fn parseFunction(allocator: Allocator, stream: *properties.Stream, slot: Slot, name: []const u8) Allocator.Error!?[]u8 {
    if (stream.next().token_type != .left_paren) return null;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, name);
    try out.append(allocator, '(');
    var count: usize = 0;
    while (true) {
        const token = stream.next();
        // Fonts4 §6.8 is <ident>, not <custom-ident>: keyword-shaped names
        // inside the function remain ordinary case-sensitive names.
        if (token.token_type != .ident) return null;
        const decoded = try tokens.decode(allocator, token.value);
        defer allocator.free(decoded);
        const escaped = try serial.serializeIdentifier(allocator, decoded);
        defer allocator.free(escaped);
        if (count != 0) try out.appendSlice(allocator, ", ");
        try out.appendSlice(allocator, escaped);
        count += 1;
        if (stream.peek().token_type != .comma) break;
        if (slot != .styleset and slot != .character_variant) return null;
        _ = stream.next();
    }
    if (stream.next().token_type != .right_paren) return null;
    try out.append(allocator, ')');
    return try out.toOwnedSlice(allocator);
}

/// Fonts4 §6.11: normal resets seven longhands; none changes only ligatures.
pub fn parseShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var components = (try parseComponents(options.allocator, stream, null)) orelse return false;
    defer components.deinit(options.allocator);
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, 0..) |l, i| {
        const v = try components.value(options.allocator, @enumFromInt(i));
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    return true;
}

/// CSSOM §6.7.2; Blink StylePropertySerializer::FontVariantValue uses the
/// same rule: ligatures none cannot combine with another non-normal value.
/// This implementation uses Crane's owned values, not Blink's code.
pub fn serialize(vs: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    std.debug.assert(vs.len == longhands.len);
    const none = vs[0].value == .keyword and vs[0].value.keyword == .none;
    if (none) {
        for (vs[1..]) |v| if (!isNormal(v.value)) return false;
        try out.appendSlice(allocator, "none");
        return true;
    }
    const start = out.items.len;
    for (vs, longhands) |v, l| {
        if (isNormal(v.value)) continue;
        if (out.items.len != start) try out.append(allocator, ' ');
        try properties.serializeValue(l, v.value, out, allocator);
    }
    if (out.items.len == start) try out.appendSlice(allocator, "normal");
    return true;
}
fn isNormal(v: Value) bool {
    // Q28: pending system-font longhands serialize empty and are skipped.
    return v == .font_system or (v == .keyword and v.keyword == .normal);
}
fn take(stream: *properties.Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokens.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}
