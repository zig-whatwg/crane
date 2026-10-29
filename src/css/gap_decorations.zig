//! CSS Gap Decorations 1 (https://drafts.csswg.org/css-gaps-1/): the gap
//! decoration properties' values - parsing, computed values and CSSOM
//! serialization. Painting and geometry are a layout concern; nothing here
//! supplies them.
//!
//! - §4.1-4.3: column-rule-color/style/width and row-rule-* are LISTS of
//!   values and repeat() notations (§4.5), superseding Multicol 1's single
//!   values. A list of one plain item is stored as that plain Value, exactly
//!   as the classic multicol longhand (box_multicol_values.zig, row 125); any
//!   other list is one `List` (Value.gap_list), shared by reference.
//! - §4.4/§4.8: column-rule, row-rule and rule expand <gap-rule> lists into
//!   their longhands and serialize back only when the longhands are
//!   "repeater aligned".
//! - §§3.2-3.5: the -break, -inset, -visibility-items and rule-overlap
//!   properties and their shorthands.
//!
//! Browser evidence (golden rule 2): wpt.fyi stable runs at WPT 07ce6e987a
//! (2026-10-29), css/css-gaps/parsing: Chrome 156 1750/1750, Firefox 159
//! 357, Safari 27 360 (only the -invalid files and single values). Chrome
//! ships the spec; Firefox and Safari have not implemented it and have not
//! declined it (no negative standards position, no WontFix), so the spec
//! and the shipping browser decide.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Color = values.Color;
const Keyword = values.Keyword;
const Longhand = properties.Longhand;
const Shorthand = properties.Shorthand;
const Stream = properties.Stream;
const Assignment = properties.Assignment;
const Assigned = properties.Assigned;

/// Which gap decoration list a longhand holds.
pub const Kind = enum { color, style, width };

pub fn kindOf(l: Longhand) Kind {
    return switch (l) {
        .column_rule_color, .row_rule_color => .color,
        .column_rule_style, .row_rule_style => .style,
        .column_rule_width, .row_rule_width => .width,
        else => unreachable,
    };
}

/// <line-style>: border-style's keywords (§4.2).
const line_styles = [_]Keyword{ .none, .hidden, .dotted, .dashed, .solid, .double, .groove, .ridge, .inset, .outset };

/// How an item of a list repeats (§4.5).
pub const Repeat = enum { single, integer, auto };

pub const Item = struct {
    repeat: Repeat,
    /// An integer repeater's <integer [1,∞]>: an integer, or a calculation
    /// until it is computed. Unused (auto) otherwise.
    count: Value = Value.kw(.auto),
    /// One value for a single item; the repeated values otherwise.
    values: []Value,

    fn deinit(self: Item, allocator: Allocator) void {
        if (self.repeat == .integer) self.count.release();
        for (self.values) |v| v.release();
        allocator.free(self.values);
    }

    fn sameShape(a: Item, b: Item) bool {
        if (a.repeat != b.repeat or a.values.len != b.values.len) return false;
        return a.repeat != .integer or a.count.eql(b.count);
    }
};

/// A gap decoration list of two or more items, or of one repeat(). Immutable
/// once made; every holder takes a reference.
pub const List = struct {
    allocator: Allocator,
    refs: std.atomic.Value(usize) = .init(1),
    items: []Item,

    /// Takes ownership of `items` (allocated with `allocator`).
    fn create(allocator: Allocator, items: []Item) Allocator.Error!*List {
        const self = try allocator.create(List);
        self.* = .{ .allocator = allocator, .items = items };
        return self;
    }

    pub fn ref(self: *List) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *List) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| item.deinit(self.allocator);
        self.allocator.free(self.items);
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const List, other: *const List) bool {
        if (self == other) return true;
        if (self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| {
            if (!a.sameShape(b)) return false;
            for (a.values, b.values) |x, y| if (!x.eql(y)) return false;
        }
        return true;
    }

    /// A new list of `mapper.leaf(value)` for every value and
    /// `mapper.count(count)` for every integer repeater's count.
    fn map(self: *const List, allocator: Allocator, mapper: anytype) Allocator.Error!*List {
        const items = try allocator.alloc(Item, self.items.len);
        var done: usize = 0;
        errdefer {
            for (items[0..done]) |item| item.deinit(allocator);
            allocator.free(items);
        }
        for (self.items, items) |source, *target| {
            const mapped = try allocator.alloc(Value, source.values.len);
            var n: usize = 0;
            errdefer {
                for (mapped[0..n]) |v| v.release();
                allocator.free(mapped);
            }
            for (source.values) |v| {
                mapped[n] = try mapper.leaf(v);
                n += 1;
            }
            const count = if (source.repeat == .integer) try mapper.count(source.count) else Value.kw(.auto);
            target.* = .{ .repeat = source.repeat, .count = count, .values = mapped };
            done += 1;
        }
        return create(allocator, items);
    }

    /// Computed value (§4.1-4.3): each value through the longhand's own
    /// conversion (`context.component`, as a plain value of `l` computes),
    /// each count through the <integer [1,∞]> conversion.
    pub fn compute(self: *const List, allocator: Allocator, l: Longhand, context: anytype) Allocator.Error!*List {
        return self.map(allocator, ComputeMapper(@TypeOf(context)){ .l = l, .context = context });
    }

    /// CSSOM §9's resolved value: currentcolor becomes this element's color.
    pub fn resolveColors(self: *const List, allocator: Allocator, context: Color.Context) Allocator.Error!*List {
        const Mapper = struct {
            allocator: Allocator,
            context: Color.Context,
            fn leaf(m: @This(), v: Value) Allocator.Error!Value {
                if (v == .color) return .{ .color = try v.color.resolveComputed(m.allocator, m.context) };
                v.retain();
                return v;
            }
            fn count(_: @This(), v: Value) Allocator.Error!Value {
                v.retain();
                return v;
            }
        };
        return self.map(allocator, Mapper{ .allocator = allocator, .context = context });
    }

    pub fn serialize(self: *const List, l: Longhand, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items, 0..) |item, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            if (item.repeat == .single) {
                try properties.serializeValue(l, item.values[0], out, allocator);
                continue;
            }
            try openRepeat(item, out, allocator);
            for (item.values, 0..) |v, j| {
                if (j != 0) try out.appendSlice(allocator, ", ");
                try properties.serializeValue(l, v, out, allocator);
            }
            try out.append(allocator, ')');
        }
    }

    pub fn needsUnavailableMetrics(self: *const List, geometry_length: bool) bool {
        for (self.items) |item| {
            if (item.repeat == .integer and item.count.needsUnavailableMetrics(geometry_length)) return true;
            for (item.values) |v| if (v.needsUnavailableMetrics(geometry_length)) return true;
        }
        return false;
    }

    pub fn needsTreeCounts(self: *const List) bool {
        for (self.items) |item| {
            if (item.repeat == .integer and item.count.needsTreeCounts()) return true;
            for (item.values) |v| if (v.needsTreeCounts()) return true;
        }
        return false;
    }

    pub fn needsRandomBase(self: *const List) bool {
        for (self.items) |item| {
            if (item.repeat == .integer and item.count.needsRandomBase()) return true;
            for (item.values) |v| if (v.needsRandomBase()) return true;
        }
        return false;
    }
};

fn ComputeMapper(comptime Context: type) type {
    return struct {
        l: Longhand,
        context: Context,
        fn leaf(m: @This(), v: Value) Allocator.Error!Value {
            return m.context.component(m.l, v);
        }
        fn count(m: @This(), v: Value) Allocator.Error!Value {
            // column-count is the same <integer [1,∞]>: a calculation rounds
            // and clamps into range when it is computed.
            return m.context.component(.column_count, v);
        }
    };
}

/// A value of a list longhand with currentcolor resolved for the receiving
/// element (CSSOM §9); owned by the caller. A plain value is resolved as the
/// classic longhand's is.
pub fn resolveValue(allocator: Allocator, value: Value, context: Color.Context) Allocator.Error!Value {
    if (value == .gap_list) return .{ .gap_list = try value.gap_list.resolveColors(allocator, context) };
    if (value == .color) return .{ .color = try value.color.resolveComputed(allocator, context) };
    value.retain();
    return value;
}

/// getComputedStyle's serialization of a list longhand's computed list.
pub fn serializeResolved(l: Longhand, list: *const List, context: Color.Context, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const resolved = try list.resolveColors(allocator, context);
    defer resolved.unref();
    try resolved.serialize(l, out, allocator);
}

fn openRepeat(item: Item, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, "repeat(");
    if (item.repeat == .auto)
        try out.appendSlice(allocator, "auto")
    else
        try properties.serializeValue(.column_count, item.count, out, allocator);
    try out.appendSlice(allocator, ", ");
}

/// A value's items: a gap list's, or a plain value as one single item.
/// The view borrows `value` and never writes through it.
fn itemsOf(value: *const Value, buffer: *[1]Item) []const Item {
    if (value.* == .gap_list) return value.gap_list.items;
    buffer[0] = .{ .repeat = .single, .values = @constCast(value)[0..1] };
    return buffer;
}

// ============================================================================
// Parsing
// ============================================================================

fn takeKeyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| {
        if (tokenizer.nameEql(token.value, candidate.name())) {
            _ = stream.next();
            return candidate;
        }
    }
    return null;
}

/// The end of a list item: a comma, the end of repeat(), or the end.
fn atSeparator(stream: *Stream) bool {
    return switch (stream.peek().token_type) {
        .comma, .right_paren, .eof => true,
        else => false,
    };
}

/// One <color>, <line-style> or <line-width> of longhand `l`.
fn parseItem(options: properties.ParseOptions, kind: Kind, l: Longhand, stream: *Stream) Allocator.Error!?Value {
    return switch (kind) {
        .color => properties.colorValue(options, stream, l.info()),
        .style => if (takeKeyword(stream, &line_styles)) |k| Value.kw(k) else null,
        // <line-width> = <length [0,∞]> | thin | medium | thick.
        .width => if (takeKeyword(stream, &.{ .thin, .medium, .thick })) |k|
            Value.kw(k)
        else
            properties.lengthPercentage(options, stream, .{ .negative = false, .percent = false, .quirky = false }),
    };
}

/// A list longhand's value: <line-*-list> | <auto-line-*-list> (§§4.1-4.3).
pub fn consume(options: properties.ParseOptions, l: Longhand, stream: *Stream) Allocator.Error!?Value {
    const Element = struct {
        l: Longhand,
        fn parse(self: @This(), o: properties.ParseOptions, s: *Stream) Allocator.Error!?[1]Value {
            const v = try parseItem(o, kindOf(self.l), self.l, s) orelse return null;
            return .{v};
        }
    };
    const parsed = try parseLists(1, options, stream, Element{ .l = l }) orelse return null;
    return parsed[0];
}

/// <gap-rule> = <line-width> || <line-style> || <color> (§4.4), each
/// omitted component its longhand's initial value.
const GapRule = struct {
    fn parse(_: GapRule, options: properties.ParseOptions, stream: *Stream) Allocator.Error!?[3]Value {
        const kinds = [3]Kind{ .width, .style, .color };
        const parts_longhands = [3]Longhand{ .column_rule_width, .column_rule_style, .column_rule_color };
        var parts: [3]?Value = .{ null, null, null };
        defer for (parts) |part| if (part) |v| v.release();
        var taken: usize = 0;
        while (taken < 3 and !atSeparator(stream)) : (taken += 1) {
            const found = for (kinds, parts_longhands, &parts) |kind, l, *part| {
                if (part.* != null) continue;
                // An alternative that does not match leaves the stream where
                // it was for the next one (lesson debugging-optional-css-
                // groups-must-restore-the-token-stream).
                var trial = stream.*;
                if (try parseItem(options, kind, l, &trial)) |v| {
                    part.* = v;
                    stream.* = trial;
                    break true;
                }
            } else false;
            if (!found) return null;
        }
        if (taken == 0 or !atSeparator(stream)) return null;
        var out: [3]Value = undefined;
        for (&out, &parts, parts_longhands) |*slot, *part, l| {
            slot.* = part.* orelse l.info().initial;
            part.* = null;
        }
        return out;
    }
};

/// Parse `<x-or-repeat>#` with at most one auto repeater (§4.5), where an
/// element of `x` is `N` values that go one to each of N parallel lists
/// (N is 3 for a <gap-rule>: its width, style and color lists). Null when
/// the grammar does not match; allocation failure is an error.
fn parseLists(comptime N: usize, options: properties.ParseOptions, stream: *Stream, element: anytype) Allocator.Error!?[N]Value {
    const allocator = options.allocator;
    var lists: [N]std.ArrayList(Item) = @splat(.empty);
    defer for (&lists) |*list| {
        for (list.items) |item| item.deinit(allocator);
        list.deinit(allocator);
    };
    var autos: usize = 0;
    while (true) {
        for (&lists) |*list| try list.ensureUnusedCapacity(allocator, 1);
        const token = stream.peek();
        if (token.token_type == .function and tokenizer.nameEql(token.value, "repeat")) {
            _ = stream.next();
            // This stream yields a function's `(` as a token of its own.
            if (stream.next().token_type != .left_paren) return null;
            if (!try parseRepeat(N, options, stream, element, &lists, &autos)) return null;
        } else {
            const parsed = try element.parse(options, stream) orelse return null;
            var released = false;
            defer if (!released) for (parsed) |v| v.release();
            var slices: [N][]Value = undefined;
            var made: usize = 0;
            errdefer for (slices[0..made]) |slice| allocator.free(slice);
            for (&slices) |*slice| {
                slice.* = try allocator.alloc(Value, 1);
                made += 1;
            }
            for (&lists, slices, parsed) |*list, slice, v| {
                slice[0] = v;
                list.appendAssumeCapacity(.{ .repeat = .single, .values = slice });
            }
            released = true;
        }
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    return try finish(N, allocator, &lists);
}

/// After `repeat(`: `[ <integer [1,∞]> | auto ] , <x>#` and `)` (or the end
/// of the value, which closes it, Syntax 3 §5.4.8).
fn parseRepeat(comptime N: usize, options: properties.ParseOptions, stream: *Stream, element: anytype, lists: *[N]std.ArrayList(Item), autos: *usize) Allocator.Error!bool {
    const allocator = options.allocator;
    var repeat: Repeat = .auto;
    var count = Value.kw(.auto);
    if (takeKeyword(stream, &.{.auto}) != null) {
        // "At most one repeat() in a given list of values may be an auto
        // repeater."
        autos.* += 1;
        if (autos.* > 1) return false;
    } else {
        count = try @import("box_values.zig").consumeInteger(options, stream, 1) orelse return false;
        repeat = .integer;
    }
    defer if (repeat == .integer) count.release();
    if (stream.next().token_type != .comma) return false;
    var inner: [N]std.ArrayList(Value) = @splat(.empty);
    defer for (&inner) |*list| {
        for (list.items) |v| v.release();
        list.deinit(allocator);
    };
    while (true) {
        for (&inner) |*list| try list.ensureUnusedCapacity(allocator, 1);
        const parsed = try element.parse(options, stream) orelse return false;
        for (&inner, parsed) |*list, v| list.appendAssumeCapacity(v);
        switch (stream.next().token_type) {
            .comma => continue,
            .right_paren, .eof => break,
            else => return false,
        }
    }
    var slices: [N][]Value = undefined;
    var made: usize = 0;
    errdefer for (slices[0..made]) |slice| allocator.free(slice);
    for (&slices, inner) |*slice, list| {
        slice.* = try allocator.alloc(Value, list.items.len);
        made += 1;
    }
    for (lists, slices, &inner) |*list, slice, *source| {
        @memcpy(slice, source.items);
        source.clearRetainingCapacity();
        if (repeat == .integer) count.retain();
        list.appendAssumeCapacity(.{ .repeat = repeat, .count = count, .values = slice });
    }
    return true;
}

/// One plain item: the plain values, as the classic longhands store them.
/// Anything else: a List per value.
fn finish(comptime N: usize, allocator: Allocator, lists: *[N]std.ArrayList(Item)) Allocator.Error![N]Value {
    var out: [N]Value = undefined;
    if (lists[0].items.len == 1 and lists[0].items[0].repeat == .single) {
        for (lists, &out) |*list, *slot| {
            const item = list.items[0];
            slot.* = item.values[0];
            allocator.free(item.values);
            list.clearRetainingCapacity();
        }
        return out;
    }
    var made: usize = 0;
    errdefer for (out[0..made]) |v| v.release();
    for (lists, &out) |*list, *slot| {
        const created = try allocator.create(List);
        const items = list.toOwnedSlice(allocator) catch |err| {
            allocator.destroy(created);
            return err;
        };
        created.* = .{ .allocator = allocator, .items = items };
        slot.* = .{ .gap_list = created };
        made += 1;
    }
    return out;
}

/// <inset-value> = <length-percentage> | overlap-join (§3.3).
pub fn consumeInset(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (takeKeyword(stream, &.{.overlap_join})) |k| return Value.kw(k);
    return properties.lengthPercentage(options, stream, .{ .negative = true, .quirky = false });
}

// ============================================================================
// Shorthands
// ============================================================================

const Form = enum {
    /// <gap-rule-list> | <gap-auto-rule-list>: width, style, color.
    rule,
    /// One list longhand's grammar.
    list,
    /// One keyword longhand's grammar.
    keyword,
    /// cap-start cap-end? [ / junction-start junction-end? ]?
    inset_full,
    /// <inset-value> <inset-value>?: start, end.
    inset_pair,
    /// <inset-value>: the cap and the junction value.
    inset_same,

    fn width(self: Form) usize {
        return switch (self) {
            .rule => 3,
            .list, .keyword => 1,
            .inset_full => 4,
            .inset_pair, .inset_same => 2,
        };
    }
};

/// A shorthand's grammar, for one axis or for both (the rule-* shorthands
/// set the column and the row longhands to the same value).
const Shape = struct { form: Form, both: bool };

fn shapeOf(s: Shorthand) Shape {
    return switch (s) {
        .column_rule, .row_rule => .{ .form = .rule, .both = false },
        .rule => .{ .form = .rule, .both = true },
        .rule_color, .rule_style, .rule_width => .{ .form = .list, .both = true },
        .rule_break, .rule_visibility_items => .{ .form = .keyword, .both = true },
        .column_rule_inset, .row_rule_inset => .{ .form = .inset_full, .both = false },
        .rule_inset => .{ .form = .inset_full, .both = true },
        .column_rule_inset_cap, .column_rule_inset_junction, .row_rule_inset_cap, .row_rule_inset_junction => .{ .form = .inset_pair, .both = false },
        .rule_inset_cap, .rule_inset_junction => .{ .form = .inset_pair, .both = true },
        .column_rule_inset_start, .column_rule_inset_end, .row_rule_inset_start, .row_rule_inset_end => .{ .form = .inset_same, .both = false },
        .rule_inset_start, .rule_inset_end => .{ .form = .inset_same, .both = true },
        else => unreachable,
    };
}

/// The longhands of a gap decoration shorthand: one axis's, then (for a
/// both-axis shorthand) the row axis's in the same order.
pub fn longhands(s: Shorthand) []const Longhand {
    return switch (s) {
        .column_rule => &.{ .column_rule_width, .column_rule_style, .column_rule_color },
        .row_rule => &.{ .row_rule_width, .row_rule_style, .row_rule_color },
        .rule => &.{ .column_rule_width, .column_rule_style, .column_rule_color, .row_rule_width, .row_rule_style, .row_rule_color },
        .rule_color => &.{ .column_rule_color, .row_rule_color },
        .rule_style => &.{ .column_rule_style, .row_rule_style },
        .rule_width => &.{ .column_rule_width, .row_rule_width },
        .rule_break => &.{ .column_rule_break, .row_rule_break },
        .rule_visibility_items => &.{ .column_rule_visibility_items, .row_rule_visibility_items },
        .column_rule_inset => &.{ .column_rule_inset_cap_start, .column_rule_inset_cap_end, .column_rule_inset_junction_start, .column_rule_inset_junction_end },
        .row_rule_inset => &.{ .row_rule_inset_cap_start, .row_rule_inset_cap_end, .row_rule_inset_junction_start, .row_rule_inset_junction_end },
        .rule_inset => &.{ .column_rule_inset_cap_start, .column_rule_inset_cap_end, .column_rule_inset_junction_start, .column_rule_inset_junction_end, .row_rule_inset_cap_start, .row_rule_inset_cap_end, .row_rule_inset_junction_start, .row_rule_inset_junction_end },
        .column_rule_inset_cap => &.{ .column_rule_inset_cap_start, .column_rule_inset_cap_end },
        .column_rule_inset_junction => &.{ .column_rule_inset_junction_start, .column_rule_inset_junction_end },
        .row_rule_inset_cap => &.{ .row_rule_inset_cap_start, .row_rule_inset_cap_end },
        .row_rule_inset_junction => &.{ .row_rule_inset_junction_start, .row_rule_inset_junction_end },
        .rule_inset_cap => &.{ .column_rule_inset_cap_start, .column_rule_inset_cap_end, .row_rule_inset_cap_start, .row_rule_inset_cap_end },
        .rule_inset_junction => &.{ .column_rule_inset_junction_start, .column_rule_inset_junction_end, .row_rule_inset_junction_start, .row_rule_inset_junction_end },
        .column_rule_inset_start => &.{ .column_rule_inset_cap_start, .column_rule_inset_junction_start },
        .column_rule_inset_end => &.{ .column_rule_inset_cap_end, .column_rule_inset_junction_end },
        .row_rule_inset_start => &.{ .row_rule_inset_cap_start, .row_rule_inset_junction_start },
        .row_rule_inset_end => &.{ .row_rule_inset_cap_end, .row_rule_inset_junction_end },
        .rule_inset_start => &.{ .column_rule_inset_cap_start, .column_rule_inset_junction_start, .row_rule_inset_cap_start, .row_rule_inset_junction_start },
        .rule_inset_end => &.{ .column_rule_inset_cap_end, .column_rule_inset_junction_end, .row_rule_inset_cap_end, .row_rule_inset_junction_end },
        else => unreachable,
    };
}

fn isSlash(stream: *Stream) bool {
    const token = stream.peek();
    return token.token_type == .delim and std.mem.eql(u8, token.value, "/");
}

/// One axis's values, parsed in `form`; null on a grammar mismatch.
fn parseAxis(options: properties.ParseOptions, form: Form, first: Longhand, stream: *Stream, out: *[4]Value) Allocator.Error!bool {
    switch (form) {
        .rule => {
            const parsed = try parseLists(3, options, stream, GapRule{}) orelse return false;
            out[0..3].* = parsed;
        },
        .list => out[0] = try consume(options, first, stream) orelse return false,
        .keyword => out[0] = try properties.parseLonghand(options, first, stream) orelse return false,
        .inset_same => {
            const v = try consumeInset(options, stream) orelse return false;
            v.retain();
            out[0..2].* = .{ v, v };
        },
        .inset_pair => {
            const start = try consumeInset(options, stream) orelse return false;
            errdefer start.release();
            const end = if (stream.atEnd()) retained(start) else try consumeInset(options, stream) orelse {
                start.release();
                return false;
            };
            out[0..2].* = .{ start, end };
        },
        .inset_full => {
            // §3.3.3: "1. If the junction values are omitted, they are
            // copied from the cap values. 2. Any omitted end value is
            // copied from the corresponding start value."
            var parts: [4]?Value = .{ null, null, null, null };
            defer for (parts) |part| if (part) |v| v.release();
            parts[0] = try consumeInset(options, stream) orelse return false;
            if (!stream.atEnd() and !isSlash(stream))
                parts[1] = try consumeInset(options, stream) orelse return false;
            if (isSlash(stream)) {
                _ = stream.next();
                parts[2] = try consumeInset(options, stream) orelse return false;
                if (!stream.atEnd()) parts[3] = try consumeInset(options, stream) orelse return false;
            }
            if (!stream.atEnd()) return false;
            if (parts[1] == null) parts[1] = retained(parts[0].?);
            if (parts[2] == null) {
                parts[2] = retained(parts[0].?);
                parts[3] = retained(parts[1].?);
            }
            if (parts[3] == null) parts[3] = retained(parts[2].?);
            for (out, &parts) |*slot, *part| {
                slot.* = part.*.?;
                part.* = null;
            }
        },
    }
    return true;
}

fn retained(v: Value) Value {
    v.retain();
    return v;
}

pub fn parseShorthand(options: properties.ParseOptions, s: Shorthand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    const shape = shapeOf(s);
    const ls = longhands(s);
    const width = shape.form.width();
    try out.ensureUnusedCapacity(options.allocator, ls.len);
    var axis: [4]Value = undefined;
    if (!try parseAxis(options, shape.form, ls[0], stream, &axis)) return false;
    if (!stream.atEnd()) {
        for (axis[0..width]) |v| v.release();
        return false;
    }
    for (ls, 0..) |l, i| {
        const v = axis[i % width];
        // The row axis shares the column axis's values.
        if (i >= width) v.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    return true;
}

/// CSSOM "serialize a CSS value" of a gap decoration shorthand; false when
/// its longhands cannot be written as it (the caller answers "").
pub fn serializeShorthand(s: Shorthand, vs: []const Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const shape = shapeOf(s);
    const ls = longhands(s);
    const width = shape.form.width();
    if (!shape.both) return serializeAxis(shape.form, ls[0..width], vs[0..width], mode, out, allocator);
    // A both-axis shorthand sets the two axes to one value: it represents
    // them only while they serialize alike.
    var column: std.ArrayList(u8) = .empty;
    defer column.deinit(allocator);
    var row: std.ArrayList(u8) = .empty;
    defer row.deinit(allocator);
    if (!try serializeAxis(shape.form, ls[0..width], vs[0..width], mode, &column, allocator)) return false;
    if (!try serializeAxis(shape.form, ls[width..], vs[width..], mode, &row, allocator)) return false;
    if (!std.mem.eql(u8, column.items, row.items)) return false;
    try out.appendSlice(allocator, column.items);
    return true;
}

fn serializeAxis(form: Form, ls: []const Longhand, vs: []const Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    switch (form) {
        .rule => return serializeRule(ls, vs, mode, out, allocator),
        .list, .keyword => try properties.serializeValue(ls[0], vs[0].value, out, allocator),
        .inset_same => {
            if (!vs[0].value.eql(vs[1].value)) return false;
            try properties.serializeValue(ls[0], vs[0].value, out, allocator);
        },
        .inset_pair => {
            try properties.serializeValue(ls[0], vs[0].value, out, allocator);
            if (!vs[0].value.eql(vs[1].value)) {
                try out.append(allocator, ' ');
                try properties.serializeValue(ls[1], vs[1].value, out, allocator);
            }
        },
        .inset_full => {
            // Pinned by css-gaps/parsing/rule-inset-valid.html (Chrome):
            // one value when all four agree, otherwise all four.
            try properties.serializeValue(ls[0], vs[0].value, out, allocator);
            const all_same = for (vs[1..4]) |v| {
                if (!v.value.eql(vs[0].value)) break false;
            } else true;
            if (all_same) return true;
            try out.append(allocator, ' ');
            try properties.serializeValue(ls[1], vs[1].value, out, allocator);
            try out.appendSlice(allocator, " / ");
            try properties.serializeValue(ls[2], vs[2].value, out, allocator);
            try out.append(allocator, ' ');
            try properties.serializeValue(ls[3], vs[3].value, out, allocator);
        },
    }
    return true;
}

/// §4.8: column-rule/row-rule from width, style and color lists, only when
/// they are repeater aligned: as many items, and at each index the same
/// shape (single, integer repeater with an equal count, or auto) with as
/// many values.
fn serializeRule(ls: []const Longhand, vs: []const Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    var buffers: [3][1]Item = undefined;
    var lists: [3][]const Item = undefined;
    for (&lists, &buffers, vs[0..3]) |*list, *buffer, *assigned| list.* = itemsOf(&assigned.value, buffer);
    for (lists[1..]) |list| if (list.len != lists[0].len) return false;
    for (lists[0], 0..) |item, i| {
        if (!item.sameShape(lists[1][i]) or !item.sameShape(lists[2][i])) return false;
    }
    for (lists[0], 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        if (item.repeat != .single) try openRepeat(item, out, allocator);
        for (0..item.values.len) |j| {
            if (j != 0) try out.appendSlice(allocator, ", ");
            try ruleItem(ls, .{ lists[0][i].values[j], lists[1][i].values[j], lists[2][i].values[j] }, mode, out, allocator);
        }
        if (item.repeat != .single) try out.append(allocator, ')');
    }
    return true;
}

/// One <gap-rule> (row 125's Multicol 1 §4.5 serialization, per item):
/// omit initial specified components; none is omitted even in computed
/// readback. The rule's width is not zeroed when its style is none or
/// hidden (Multicol 1 §4.4, pinned WPT).
fn ruleItem(ls: []const Longhand, components: [3]Value, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var wrote = false;
    for (ls[0..3], components, 0..) |l, value, i| {
        if (i == 1 and value.isKeyword(.none)) continue;
        if (mode == .specified and value.eql(l.info().initial)) continue;
        if (wrote) try out.append(allocator, ' ');
        try properties.serializeValue(l, value, out, allocator);
        wrote = true;
    }
    // The shortest declaration setting all three initials is medium.
    if (!wrote) try properties.serializeValue(ls[0], components[0], out, allocator);
}
