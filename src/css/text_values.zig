//! CSS Text4/5 values, independent of line layout. Numeric children keep
//! their declaration's parse scope and compute before the value is inherited.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Stream = properties.Stream;

/// Text4 §7.1 match-parent; Blink TextAlign::ApplyValue resolves the
/// parent's logical alignment before inheritance, using the parent's bidi
/// direction. Safari applies the same rule to text-align-last (Q7 probe).
pub fn computeAlignment(property: properties.Longhand, value: Value, parent: ?*const @import("computed_style.zig").ComputedStyle) Value {
    if (!value.isKeyword(.match_parent)) return value;
    const source = parent orelse return Value.kw(.start);
    const inherited = source.keyword(property);
    const rtl = source.keyword(.direction) == .rtl;
    return Value.kw(switch (inherited) {
        .start => if (rtl) .right else .left,
        .end => if (rtl) .left else .right,
        else => inherited,
    });
}

pub const Components = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    property: properties.Longhand,
    items: []const Value,

    /// Borrows its input and retains it only after all allocations succeed.
    pub fn create(allocator: Allocator, property: properties.Longhand, items: []const Value) Allocator.Error!*Components {
        const owned = try allocator.dupe(Value, items);
        errdefer allocator.free(owned);
        const self = try allocator.create(Components);
        self.* = .{ .allocator = allocator, .property = property, .items = owned };
        for (owned) |item| item.retain();
        return self;
    }
    pub fn ref(self: *Components) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Components) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| item.release();
        self.allocator.free(self.items);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Components, other: *const Components) bool {
        if (self == other) return true;
        if (self.property != other.property or self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const Components, geometry_length: bool) bool {
        for (self.items) |item| if (item.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }
    pub fn needsTreeCounts(self: *const Components) bool {
        for (self.items) |item| if (item.needsTreeCounts()) return true;
        return false;
    }
    pub fn needsRandomBase(self: *const Components) bool {
        for (self.items) |item| if (item.needsRandomBase()) return true;
        return false;
    }
    pub fn serialize(self: *const Components, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        var count = self.items.len;
        // Text4 §6.3.4: after defaults to before; before defaults to auto.
        if (self.property == .hyphenate_limit_chars) {
            if (self.items[2].eql(self.items[1])) {
                count = 2;
                if (self.items[1].isKeyword(.auto)) count = 1;
            }
        }
        for (self.items[0..count], 0..) |item, i| {
            if (i != 0) try out.append(allocator, ' ');
            try properties.serializeValue(self.property, item, out, allocator);
        }
    }
    pub fn compute(self: *const Components, allocator: Allocator, context: anytype) Allocator.Error!*Components {
        var computed: [4]Value = undefined;
        var count: usize = 0;
        defer for (computed[0..count]) |item| item.release();
        for (self.items) |item| {
            // Text5 §2: consistent is the default computed fitting method.
            if (self.property == .text_fit and item.isKeyword(.consistent)) continue;
            computed[count] = try context.component(self.property, item);
            count += 1;
        }
        if (self.property == .hanging_punctuation) {
            // Safari (the sole shipping engine) preserves specified order but
            // canonicalizes the computed list. Q7's three-browser CSSOM probe.
            var next: usize = 0;
            for ([_]Keyword{ .first, .force_end, .allow_end, .last }) |k| {
                for (self.items) |item| if (item.isKeyword(k)) {
                    computed[next] = item;
                    next += 1;
                };
            }
        }
        return create(allocator, self.property, computed[0..count]);
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

/// A numeric alternative restores the stream on a type mismatch, so a
/// number-or-length grammar tries each type without retokenizing a substring.
fn numeric(options: properties.ParseOptions, stream: *Stream, grammar: math.Grammar, unitless_zero: bool) Allocator.Error!?Value {
    // Values4 §5: representation limits clamp otherwise valid integers;
    // a grammar's minimum still rejects a literal outside its allowed range.
    if (grammar.kind == .integer and stream.peek().token_type == .number) {
        const token = stream.peek();
        const n = token.numeric_value orelse return null;
        if (!token.is_integer or n < grammar.minimum) return null;
        _ = stream.next();
        return .{ .integer = @intFromFloat(@min(n, @as(f64, std.math.maxInt(i32)))) };
    }
    const start = stream.*;
    const parsed = try Number.consume(options, stream, grammar, unitless_zero) orelse {
        stream.* = start;
        return null;
    };
    return switch (parsed) {
        .calculation => |expression| .{ .calculation = expression },
        .literal => |number| switch (number.unit) {
            .number => if (grammar.kind == .integer) .{ .integer = @intFromFloat(number.value) } else .{ .number = number.value },
            .percent => .{ .length = .percent(number.value) },
            else => .{ .length = .{ .value = number.value, .unit = values.LengthUnit.fromString(number.unit.name()).? } },
        },
    };
}

pub fn parse(options: properties.ParseOptions, property: properties.Longhand, stream: *Stream) Allocator.Error!?Value {
    switch (property) {
        .white_space_trim => {
            // Text4 §4.2; WebKit's cssWhiteSpaceTrimEnabled parser/storage.
            // Q10 keeps this independent of the shipped white-space shorthand.
            if (keyword(stream, &.{.none})) |k| return Value.kw(k);
            const order = [_]Keyword{ .discard_before, .discard_after, .discard_inner };
            var present = [_]bool{ false, false, false };
            var count: usize = 0;
            while (keyword(stream, &order)) |k| {
                for (order, 0..) |candidate, i| if (candidate == k) {
                    if (present[i]) return null;
                    present[i] = true;
                    count += 1;
                };
            }
            if (count == 0) return null;
            var items: [3]Value = undefined;
            var next: usize = 0;
            for (order, present) |k, selected| if (selected) {
                items[next] = Value.kw(k);
                next += 1;
            };
            if (count == 1) return items[0];
            return .{ .text_values = try Components.create(options.allocator, property, items[0..count]) };
        },
        .hanging_punctuation => {
            // Text4 §9.2.1; specified order follows Safari and pinned WPT.
            if (keyword(stream, &.{.none})) |k| return Value.kw(k);
            var items: [3]Value = undefined;
            var count: usize = 0;
            var ending = false;
            while (keyword(stream, &.{ .first, .force_end, .allow_end, .last })) |k| {
                for (items[0..count]) |item| if (item.isKeyword(k)) return null;
                if (k == .force_end or k == .allow_end) {
                    if (ending) return null;
                    ending = true;
                }
                if (count == items.len) return null;
                items[count] = Value.kw(k);
                count += 1;
            }
            if (count == 0) return null;
            if (count == 1) return items[0];
            return .{ .text_values = try Components.create(options.allocator, property, items[0..count]) };
        },
        .hyphenate_limit_lines => {
            // Text4 §6.3.5; WebKit bug323934 landed 2026-09-11, WPT PR62629.
            if (keyword(stream, &.{.no_limit})) |k| return Value.kw(k);
            return numeric(options, stream, .{ .kind = .integer, .minimum = 0, .maximum = std.math.maxInt(i32) }, false);
        },
        .text_autospace => return parseAutospace(options, stream),
        .word_space_transform => {
            // Text4 §2.2 / CSSWG PR9242; pinned word-space-transform-valid.
            if (keyword(stream, &.{.none})) |k| return Value.kw(k);
            var phrase = keyword(stream, &.{.auto_phrase}) != null;
            const separator = keyword(stream, &.{ .space, .ideographic_space }) orelse return null;
            if (!phrase) phrase = keyword(stream, &.{.auto_phrase}) != null;
            if (!phrase) return Value.kw(separator);
            return .{ .text_values = try Components.create(options.allocator, property, &.{ Value.kw(separator), Value.kw(.auto_phrase) }) };
        },
        .hyphenate_character => {
            // Text4 §6.3.2: any CSS string, including the empty string.
            if (keyword(stream, &.{.auto})) |k| return Value.kw(k);
            const token = stream.next();
            if (token.token_type != .string) return null;
            const decoded = try tokens.decode(options.allocator, token.stringContents());
            defer options.allocator.free(decoded);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(options.allocator);
            try values.appendString(decoded, &out, options.allocator);
            return .{ .text = try values.SharedText.create(options.allocator, out.items) };
        },
        .hyphenate_limit_chars => {
            var items: [3]Value = .{ Value.kw(.auto), Value.kw(.auto), Value.kw(.auto) };
            defer for (items) |item| item.release();
            var count: usize = 0;
            while (count < 3) : (count += 1) {
                items[count] = if (keyword(stream, &.{.auto})) |k| Value.kw(k) else (try numeric(options, stream, .{ .kind = .integer, .minimum = 0, .maximum = std.math.maxInt(i32) }, false)) orelse break;
            }
            if (count == 0) return null;
            if (count == 2) {
                items[2] = items[1];
                items[2].retain();
            }
            return .{ .text_values = try Components.create(options.allocator, property, &items) };
        },
        .tab_size => {
            // Text4 §4.4: nonnegative number OR length, never percentage.
            if (try numeric(options, stream, .{ .kind = .number, .minimum = 0 }, false)) |v| return v;
            return numeric(options, stream, .{ .kind = .length, .minimum = 0 }, false);
        },
        .text_fit => {
            if (keyword(stream, &.{.none})) |k| return Value.kw(k);
            var items: [3]Value = undefined;
            var count: usize = 0;
            defer for (items[0..count]) |item| item.release();
            items[0] = Value.kw(keyword(stream, &.{ .grow, .shrink }) orelse return null);
            count = 1;
            if (keyword(stream, &.{ .consistent, .per_line, .per_line_all })) |k| {
                items[count] = Value.kw(k);
                count += 1;
            }
            // Blink ConsumeTextFit and Q7's sole shipping engine reject a
            // negative literal, while a calculation clamps at computation.
            if (try numeric(options, stream, .{ .kind = .percentage, .minimum = 0 }, false)) |v| {
                items[count] = v;
                count += 1;
            }
            return .{ .text_values = try Components.create(options.allocator, property, items[0..count]) };
        },
        .text_justify => {
            // Text4 §7.5: distribute is a legacy value alias.
            const token = stream.peek();
            if (token.token_type == .ident and tokens.nameEql(token.value, "distribute")) {
                _ = stream.next();
                return Value.kw(.inter_character);
            }
            return Value.kw(keyword(stream, &.{ .auto, .none, .inter_word, .inter_character }) orelse return null);
        },
        else => unreachable,
    }
}

fn parseAutospace(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const start = stream.*;
    const result = try consumeAutospace(options, stream);
    // A malformed optional group must not look like an absent group after
    // consuming its tokens (e.g. trim-start punctuation punctuation).
    if (result == null) stream.* = start;
    return result;
}

fn consumeAutospace(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    // Text4 §8.4 / CSSWG8263. Pinned text-autospace-valid.html explicitly
    // covers punctuation and replace, ahead of current stable implementations.
    if (keyword(stream, &.{ .normal, .auto, .no_autospace })) |k| return Value.kw(k);
    const order = [_]Keyword{ .ideograph_alpha, .ideograph_numeric, .punctuation, .insert, .replace };
    var present: [order.len]bool = .{false} ** order.len;
    var count: usize = 0;
    while (keyword(stream, &order)) |k| {
        for (order, 0..) |candidate, i| if (k == candidate) {
            if (present[i]) return null;
            present[i] = true;
            count += 1;
        };
    }
    if (count == 0 or (present[3] and present[4])) return null;
    var items: [4]Value = undefined;
    var used: usize = 0;
    for (order, present) |k, selected| if (selected) {
        items[used] = Value.kw(k);
        used += 1;
    };
    if (used == 1) return items[0];
    return .{ .text_values = try Components.create(options.allocator, .text_autospace, items[0..used]) };
}

pub fn parseSpacing(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Text4 §8.6; Blink CL6615802 enables this shorthand experimentally.
    // The presets are exclusive. Otherwise try both group orders, including
    // normal's ambiguity (normal trim-start sets autospace then trimming).
    if (keyword(stream, &.{ .none, .auto })) |preset| {
        if (!stream.atEnd()) return false;
        return appendSpacing(options, out, Value.kw(if (preset == .none) .space_all else .auto), Value.kw(if (preset == .none) .no_autospace else .auto));
    }
    const start = stream.*;
    for (0..2) |attempt| {
        stream.* = start;
        var trim: ?Keyword = null;
        var autospace: ?Value = null;
        defer if (autospace) |v| v.release();
        if (attempt == 0) trim = keyword(stream, &spacing_trim);
        autospace = try parseAutospace(options, stream);
        if (attempt == 1) trim = keyword(stream, &spacing_trim);
        if (autospace) |v| if (v.isKeyword(.auto)) continue;
        if ((trim != null or autospace != null) and stream.atEnd())
            return appendSpacing(options, out, Value.kw(trim orelse .normal), autospace orelse Value.kw(.normal));
    }
    stream.* = start;
    return false;
}

const spacing_trim = [_]Keyword{ .space_all, .normal, .space_first, .trim_start, .trim_both, .trim_all };

fn appendSpacing(options: properties.ParseOptions, out: *std.ArrayList(properties.Assignment), trim: Value, autospace: Value) Allocator.Error!bool {
    try out.ensureUnusedCapacity(options.allocator, 2);
    trim.retain();
    autospace.retain();
    out.appendAssumeCapacity(.{ .longhand = .text_spacing_trim, .value = .{ .value = trim } });
    out.appendAssumeCapacity(.{ .longhand = .text_autospace, .value = .{ .value = autospace } });
    return true;
}

pub fn serializeSpacing(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const trim = assigned[0].value;
    const autospace = assigned[1].value;
    if (trim.isKeyword(.auto) or autospace.isKeyword(.auto)) {
        if (!trim.isKeyword(.auto) or !autospace.isKeyword(.auto)) return false;
        try out.appendSlice(allocator, "auto");
    } else if (trim.isKeyword(.space_all) and autospace.isKeyword(.no_autospace)) {
        try out.appendSlice(allocator, "none");
    } else if (autospace.isKeyword(.normal)) {
        try properties.serializeValue(.text_spacing_trim, trim, out, allocator);
    } else {
        if (!trim.isKeyword(.normal)) {
            try properties.serializeValue(.text_spacing_trim, trim, out, allocator);
            try out.append(allocator, ' ');
        }
        try properties.serializeValue(.text_autospace, autospace, out, allocator);
    }
    return true;
}

pub fn parseWrap(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Text4 §5.5: unordered mode/style, each at most once, defaults reset.
    var mode: ?Keyword = null;
    var style: ?Keyword = null;
    for (0..2) |_| {
        if (mode == null) if (keyword(stream, &.{ .wrap, .nowrap })) |k| {
            mode = k;
            continue;
        };
        if (style == null) if (keyword(stream, &.{ .auto, .balance, .stable, .pretty })) |k| {
            style = k;
            continue;
        };
        break;
    }
    if ((mode == null and style == null) or !stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, 2);
    out.appendAssumeCapacity(.{ .longhand = .text_wrap_mode, .value = .{ .value = Value.kw(mode orelse .wrap) } });
    out.appendAssumeCapacity(.{ .longhand = .text_wrap_style, .value = .{ .value = Value.kw(style orelse .auto) } });
    return true;
}

pub fn serializeWrap(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const mode = assigned[0].value.keyword;
    const style = assigned[1].value.keyword;
    if (style == .auto) {
        try out.appendSlice(allocator, mode.name());
    } else {
        if (mode == .nowrap) try out.appendSlice(allocator, "nowrap ");
        try out.appendSlice(allocator, style.name());
    }
    return true;
}
