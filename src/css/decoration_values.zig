//! CSS Text Decoration 3/4 values and shorthand grouping, without layout.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Number = @import("numeric_values.zig").Number;
const Components = @import("text_values.zig").Components;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Longhand = properties.Longhand;
const Stream = properties.Stream;

/// Small keyword groups also represent non-scalar initial values without
/// allocating once per untouched style. No references or external storage.
pub const Keywords = struct {
    property: Longhand,
    items: [4]Keyword = @splat(.none),
    count: u3 = 0,

    pub fn init(property: Longhand, items: []const Keyword) Keywords {
        std.debug.assert(items.len <= 4);
        var result = Keywords{ .property = property, .count = @intCast(items.len) };
        @memcpy(result.items[0..items.len], items);
        return result;
    }
    pub fn value(self: Keywords) Value {
        return .{ .decoration_keywords = self };
    }
    pub fn eql(self: Keywords, other: Keywords) bool {
        return self.property == other.property and std.mem.eql(Keyword, self.items[0..self.count], other.items[0..other.count]);
    }
    pub fn serialize(self: Keywords, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items[0..self.count], 0..) |item, i| {
            if (i != 0) try out.append(allocator, ' ');
            try out.appendSlice(allocator, item.name());
        }
    }
    pub fn compute(self: Keywords, writing_mode: Keyword) Keywords {
        // Q19's Chrome/Safari majority keeps explicit right only in the
        // specified value; all three omit it from the computed value.
        if (self.property == .text_emphasis_position and self.count == 2 and self.items[1] == .right)
            return init(self.property, &.{self.items[0]});
        if (self.property != .text_emphasis_style) return self;
        // Decor4 §3.1: unspecified fill is filled; unspecified shape follows
        // typographic mode. Firefox+Safari choose circle horizontally (Q12).
        var open = false;
        var shape: ?Keyword = null;
        for (self.items[0..self.count]) |item| switch (item) {
            .open => open = true,
            .filled => {},
            else => shape = item,
        };
        const selected = shape orelse switch (writing_mode) {
            .vertical_rl, .vertical_lr => Keyword.sesame,
            else => Keyword.circle,
        };
        // Filled is omitted from computed serialization in all three engines;
        // explicit specified filled stays present in Chrome+Safari (Q12).
        return if (open) init(self.property, &.{ .open, selected }) else init(self.property, &.{selected});
    }
};

fn keyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| if (tokens.nameEql(token.value, candidate.name())) {
        _ = stream.next();
        return candidate;
    };
    return null;
}

fn group(property: Longhand, stream: *Stream, order: []const Keyword) ?Keywords {
    var present: [8]bool = @splat(false);
    std.debug.assert(order.len <= present.len);
    var count: usize = 0;
    while (keyword(stream, order)) |item| {
        for (order, 0..) |candidate, i| if (candidate == item) {
            if (present[i]) return null;
            present[i] = true;
            count += 1;
        };
    }
    if (count == 0 or count > 4) return null;
    var result = Keywords.init(property, &.{});
    for (order, present[0..order.len]) |item, found| if (found) {
        result.items[result.count] = item;
        result.count += 1;
    };
    return result;
}

fn contains(grouped: Keywords, item: Keyword) bool {
    for (grouped.items[0..grouped.count]) |candidate| if (candidate == item) return true;
    return false;
}

fn numeric(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const start = stream.*;
    const number = try Number.consume(options, stream, .{ .kind = .length_percentage }, true) orelse {
        stream.* = start;
        return null;
    };
    return switch (number) {
        .calculation => |expression| .{ .calculation = expression },
        .literal => |literal| .{ .length = if (literal.unit == .percent) .percent(literal.value) else .{
            .value = literal.value,
            .unit = values.LengthUnit.fromString(literal.unit.name()).?,
        } },
    };
}

pub fn parse(options: properties.ParseOptions, property: Longhand, stream: *Stream) Allocator.Error!?Value {
    const start = stream.*;
    const result = try consume(options, property, stream);
    // Optional shorthand alternatives may not swallow malformed groups.
    if (result == null) stream.* = start;
    return result;
}

fn consume(options: properties.ParseOptions, property: Longhand, stream: *Stream) Allocator.Error!?Value {
    switch (property) {
        .text_decoration_line => {
            // Decor4 §2.1: diagnostic decorations are exclusive alternatives.
            if (keyword(stream, &.{ .none, .spelling_error, .grammar_error })) |k| return Value.kw(k);
            return (group(property, stream, &.{ .underline, .overline, .line_through, .blink }) orelse return null).value();
        },
        .text_decoration_skip_spaces => {
            // Decor4 §2.10.3; Chrome's implementation and pinned WPT (Q8/Q12).
            if (keyword(stream, &.{ .none, .all })) |k| return Value.kw(k);
            return (group(property, stream, &.{ .start, .end }) orelse return null).value();
        },
        .text_underline_position => {
            if (keyword(stream, &.{.auto})) |k| return Value.kw(k);
            const result = group(property, stream, &.{ .from_font, .under, .left, .right }) orelse return null;
            if ((contains(result, .from_font) and contains(result, .under)) or (contains(result, .left) and contains(result, .right))) return null;
            return result.value();
        },
        .text_emphasis_position => {
            // Q16: Firefox ships the exclusive auto value; Blink has its
            // flagged parser. The initial remains over/right by majority.
            if (keyword(stream, &.{.auto})) |k| return Value.kw(k);
            const result = group(property, stream, &.{ .over, .under, .left, .right }) orelse return null;
            if (contains(result, .over) == contains(result, .under)) return null;
            if (contains(result, .left) and contains(result, .right)) return null;
            // Q19 three-browser probe: C/S keep explicit right and put
            // over/under first. Only the computed value omits right.
            return result.value();
        },
        .text_emphasis_style => {
            if (keyword(stream, &.{.none})) |k| return Value.kw(k);
            if (stream.peek().token_type == .string) {
                const token = stream.next();
                const decoded = try tokens.decode(options.allocator, token.stringContents());
                defer options.allocator.free(decoded);
                var text: std.ArrayList(u8) = .empty;
                defer text.deinit(options.allocator);
                try values.appendString(decoded, &text, options.allocator);
                return .{ .text = try values.SharedText.create(options.allocator, text.items) };
            }
            const result = group(property, stream, &.{ .filled, .open, .dot, .circle, .double_circle, .triangle, .sesame }) orelse return null;
            const fills: usize = @intFromBool(contains(result, .filled)) + @as(usize, @intFromBool(contains(result, .open)));
            if (fills > 1 or result.count - fills > 1) return null;
            return result.value();
        },
        .text_decoration_thickness => {
            // Q11: thin/medium/thick are held. All browsers accept signed
            // lengths/percentages, as the pinned grammar also requires.
            if (keyword(stream, &.{ .auto, .from_font })) |k| return Value.kw(k);
            return numeric(options, stream);
        },
        .text_underline_offset => {
            if (keyword(stream, &.{.auto})) |k| return Value.kw(k);
            return numeric(options, stream);
        },
        .text_decoration_inset => {
            if (keyword(stream, &.{.auto})) |k| return Value.kw(k);
            const first = try numeric(options, stream) orelse return null;
            defer first.release();
            const second = try numeric(options, stream);
            defer if (second) |item| item.release();
            return .{ .text_values = try Components.create(options.allocator, property, &.{ first, second orelse first }) };
        },
        else => unreachable,
    }
}

pub fn parseShorthand(options: properties.ParseOptions, shorthand: properties.Shorthand, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Each <longhand> grammar is one contiguous group; the four decoration
    // or two emphasis groups may occur in any order, each at most once.
    const longhands = shorthand.longhands();
    var parsed: [4]?Value = @splat(null);
    defer for (parsed) |item| if (item) |value| value.release();
    var any = false;
    while (!stream.atEnd()) {
        var consumed = false;
        for (longhands, 0..) |property, i| {
            if (parsed[i] != null) continue;
            const start = stream.*;
            parsed[i] = try properties.parseLonghand(options, property, stream);
            if (parsed[i] != null) {
                consumed = true;
                any = true;
                break;
            }
            stream.* = start;
        }
        if (!consumed) return false;
    }
    if (!any) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, 0..) |property, i| {
        const value = parsed[i] orelse property.info().initial;
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = property, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeShorthand(shorthand: properties.Shorthand, assigned: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const longhands = shorthand.longhands();
    // CSSOM shortest forms; the computed decoration shorthand keeps symbolic
    // currentcolor until here (Q13). Emphasis exposes the resolved color.
    var count: usize = 0;
    for (longhands, assigned) |property, value| {
        if (value.value.eql(property.info().initial)) {
            if (shorthand == .text_emphasis and mode == .computed and property == .text_emphasis_style) {} else continue;
        }
        if (count != 0) try out.append(allocator, ' ');
        try properties.serializeValue(property, value.value, out, allocator);
        count += 1;
    }
    if (count == 0) try out.appendSlice(allocator, "none");
    return true;
}
