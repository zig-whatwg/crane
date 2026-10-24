//! CSS Animations 1/2 and Transitions 1/2 value lists, plus scroll attachment ranges.
//! Stores declarations and computes their values; it does not run animations.
//! Q69: CSSWG #6946/issuecomment-1233190360 makes timeline/ranges reset-only
//! in animation. Composition is independent of that shorthand.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokens = @import("tokenizer.zig");
const names = @import("keyframe_values.zig");
const Number = @import("numeric_values.zig").Number;
const Easing = @import("easing_values.zig").Easing;
const Allocator = std.mem.Allocator;
const Stream = properties.Stream;
const Longhand = properties.Longhand;
const Value = values.Value;
const Error = Allocator.Error || error{Invalid};

const Range = struct { name: ?names.Range = null, offset: Number };
const Timeline = struct {
    kind: enum { scroll, view },
    axis: enum { block, @"inline", x, y } = .block,
    scroller: enum { nearest, root, self } = .nearest,
    insets: [2]?Number = .{ null, null },

    fn release(self: Timeline) void {
        for (self.insets) |n| if (n) |number| number.unref();
    }
    fn eql(a: Timeline, b: Timeline) bool {
        if (a.kind != b.kind or a.axis != b.axis or a.scroller != b.scroller) return false;
        for (a.insets, b.insets) |x, y| {
            if ((x == null) != (y == null)) return false;
            if (x) |n| if (!n.eql(y.?)) return false;
        }
        return true;
    }
    fn serialize(self: Timeline, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, if (self.kind == .scroll) "scroll(" else "view(");
        var wrote = false;
        if (self.scroller != .nearest) {
            try out.appendSlice(allocator, @tagName(self.scroller));
            wrote = true;
        }
        if (self.axis != .block) {
            if (wrote) try out.append(allocator, ' ');
            try out.appendSlice(allocator, @tagName(self.axis));
            wrote = true;
        }
        if (self.insets[0] != null or self.insets[1] != null) {
            if (wrote) try out.append(allocator, ' ');
            if (self.insets[0]) |n| try n.serialize(out, allocator) else try out.appendSlice(allocator, "auto");
            const same = if (self.insets[0]) |n| if (self.insets[1]) |m| n.eql(m) else false else self.insets[1] == null;
            if (!same) {
                try out.append(allocator, ' ');
                if (self.insets[1]) |n| try n.serialize(out, allocator) else try out.appendSlice(allocator, "auto");
            }
        }
        try out.append(allocator, ')');
    }
};

pub const Item = union(enum) {
    keyword: values.Keyword,
    number: Number,
    name: []const u8,
    easing: *Easing,
    range: Range,
    timeline: Timeline,

    fn release(self: Item, allocator: Allocator) void {
        switch (self) {
            .keyword => {},
            .number => |n| n.unref(),
            .name => |name| allocator.free(name),
            .easing => |e| e.unref(),
            .range => |r| r.offset.unref(),
            .timeline => |t| t.release(),
        }
    }
    fn eql(a: Item, b: Item) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .keyword => |k| k == b.keyword,
            .number => |n| n.eql(b.number),
            .name => |n| std.mem.eql(u8, n, b.name),
            .easing => |e| e.eql(b.easing),
            .range => |r| r.name == b.range.name and r.offset.eql(b.range.offset),
            .timeline => |t| t.eql(b.timeline),
        };
    }
    fn compute(self: Item, allocator: Allocator, context: math.Context) Allocator.Error!Item {
        return switch (self) {
            .keyword => self,
            .name => |n| .{ .name = try allocator.dupe(u8, n) },
            .number => |n| .{ .number = try n.compute(allocator, context) },
            .easing => |e| .{ .easing = try e.compute(allocator, context) },
            .range => |r| .{ .range = .{ .name = r.name, .offset = try r.offset.compute(allocator, context) } },
            .timeline => |t| blk: {
                var result = t;
                result.insets = .{ null, null };
                errdefer result.release();
                for (t.insets, 0..) |n, i| if (n) |number| {
                    result.insets[i] = try number.compute(allocator, context);
                };
                break :blk .{ .timeline = result };
            },
        };
    }
    fn serialize(self: Item, l: Longhand, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .keyword => |k| try out.appendSlice(allocator, k.name()),
            .number => |n| try n.serialize(out, allocator),
            .name => |name| try names.serializeName(name, out, allocator),
            .easing => |e| try e.serialize(out, allocator),
            .timeline => |t| try t.serialize(out, allocator),
            .range => |r| {
                if (r.name) |name| {
                    try out.appendSlice(allocator, name.name());
                    if (defaultOffset(r.offset, l == .animation_range_end)) return;
                    try out.append(allocator, ' ');
                }
                try r.offset.serialize(out, allocator);
            },
        }
    }
    fn needsUnavailableMetrics(self: Item) bool {
        return switch (self) {
            .number => |n| n.needsUnavailableMetrics(false),
            .range => |r| r.offset.needsUnavailableMetrics(true),
            .easing => |e| e.needsUnavailableMetrics(),
            .timeline => |t| blk: {
                for (t.insets) |n| if (n) |number| if (number.needsUnavailableMetrics(true)) break :blk true;
                break :blk false;
            },
            .keyword, .name => false,
        };
    }
    fn needsTreeCounts(self: Item) bool {
        return switch (self) {
            .number => |n| n.needsTreeCounts(),
            .range => |r| r.offset.needsTreeCounts(),
            .easing => |e| e.needsTreeCounts(),
            .timeline => |t| blk: {
                for (t.insets) |n| if (n) |number| if (number.needsTreeCounts()) break :blk true;
                break :blk false;
            },
            .keyword, .name => false,
        };
    }

    fn needsRandomBase(self: Item) bool {
        return switch (self) {
            .number => |n| n.needsRandomBase(),
            .range => |r| r.offset.needsRandomBase(),
            .easing => |e| e.needsRandomBase(),
            .timeline => |t| blk: {
                for (t.insets) |n| if (n) |number| if (number.needsRandomBase()) break :blk true;
                break :blk false;
            },
            .keyword, .name => false,
        };
    }
    fn isKeyword(self: Item, keyword: values.Keyword) bool {
        return self == .keyword and self.keyword == keyword;
    }
};

pub const List = struct {
    allocator: Allocator,
    refs: std.atomic.Value(usize) = std.atomic.Value(usize).init(1),
    property: Longhand,
    items: std.ArrayList(Item) = .empty,

    fn create(allocator: Allocator, property: Longhand) Allocator.Error!*List {
        const self = try allocator.create(List);
        self.* = .{ .allocator = allocator, .property = property };
        return self;
    }
    pub fn ref(self: *List) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *List) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items.items) |item| item.release(self.allocator);
        self.items.deinit(self.allocator);
        self.allocator.destroy(self);
    }
    fn append(self: *List, item: Item) Allocator.Error!void {
        errdefer item.release(self.allocator);
        try self.items.append(self.allocator, item);
    }
    pub fn eql(a: *const List, b: *const List) bool {
        if (a == b) return true;
        if (a.property != b.property or a.items.items.len != b.items.items.len) return false;
        for (a.items.items, b.items.items) |x, y| if (!x.eql(y)) return false;
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const List) bool {
        for (self.items.items) |item| if (item.needsUnavailableMetrics()) return true;
        return false;
    }
    pub fn needsTreeCounts(self: *const List) bool {
        for (self.items.items) |item| if (item.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const List) bool {
        for (self.items.items) |item| if (item.needsRandomBase()) return true;
        return false;
    }
    pub fn consume(options: properties.ParseOptions, l: Longhand, stream: *Stream) Allocator.Error!?*List {
        const self = try create(options.allocator, l);
        var success = false;
        defer if (!success) self.unref();
        while (true) {
            try self.append(try consumeItem(options, l, stream) orelse return null);
            if (stream.peek().token_type != .comma) break;
            _ = stream.next();
        }
        // Transitions 1 §2.1: none is the entire property list.
        if (l == .transition_property and !self.validTransitionProperties()) return null;
        success = true;
        return self;
    }
    fn validTransitionProperties(self: *const List) bool {
        if (self.items.items.len <= 1) return true;
        for (self.items.items) |item| if (item.isKeyword(.none)) return false;
        return true;
    }
    pub fn compute(self: *const List, allocator: Allocator, context: math.Context) Allocator.Error!*List {
        const result = try create(allocator, self.property);
        errdefer result.unref();
        for (self.items.items) |item| try result.append(try item.compute(allocator, context));
        return result;
    }
    pub fn serialize(self: *const List, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items.items, 0..) |item, i| {
            if (i > 0) try out.appendSlice(allocator, ", ");
            try item.serialize(self.property, out, allocator);
        }
    }
};

fn defaultOffset(n: Number, end: bool) bool {
    // Calculations remain calculations at specified time, even calc(0%).
    return n == .literal and n.literal.unit == .percent and n.literal.value == (if (end) @as(f64, 100) else 0);
}
fn ident(stream: *Stream, text: []const u8) bool {
    const t = stream.peek();
    if (t.token_type != .ident or !tokens.nameEql(t.value, text)) return false;
    _ = stream.next();
    return true;
}
fn consumeNumber(options: properties.ParseOptions, stream: *Stream, grammar: math.Grammar, zero: bool) Allocator.Error!?Item {
    return .{ .number = try Number.consume(options, stream, grammar, zero) orelse return null };
}
fn consumeItem(options: properties.ParseOptions, l: Longhand, stream: *Stream) Allocator.Error!?Item {
    const start = stream.*;
    const result = try parseItem(options, l, stream);
    if (result == null) stream.* = start;
    return result;
}
fn parseItem(options: properties.ParseOptions, l: Longhand, stream: *Stream) Allocator.Error!?Item {
    const keywords: []const values.Keyword = switch (l) {
        .animation_duration, .animation_timeline => &.{.auto},
        .animation_name, .animation_fill_mode => &.{.none},
        .animation_iteration_count => &.{.infinite},
        .animation_range_start, .animation_range_end => &.{.normal},
        .transition_property => &.{ .all, .none },
        .transition_behavior => &.{ .normal, .allow_discrete },
        .animation_direction => &.{ .normal, .reverse, .alternate, .alternate_reverse },
        .animation_play_state => &.{ .running, .paused },
        .animation_composition => &.{ .replace, .add, .accumulate },
        else => &.{},
    };
    for (keywords) |keyword| if (ident(stream, keyword.name())) return .{ .keyword = keyword };
    switch (l) {
        .animation_duration, .transition_duration => return consumeNumber(options, stream, .{ .kind = .time, .minimum = 0 }, false),
        .animation_delay, .transition_delay => return consumeNumber(options, stream, .{ .kind = .time }, false),
        .animation_iteration_count => return consumeNumber(options, stream, .{ .kind = .number, .minimum = 0 }, false),
        .animation_timing_function, .transition_timing_function => return .{ .easing = try Easing.consume(options, stream) orelse return null },
        .transition_property => {
            if (stream.peek().token_type != .ident) return null;
            const name = try names.consumeName(options.allocator, stream) orelse return null;
            // Transitions 1 §2.1 / Blink ConsumeTransitionProperty: known
            // property names are ASCII-insensitive; unknown identifiers keep
            // their case. Preserve a recognized legacy alias's own spelling.
            if (properties.lookup(name) != null) for (name) |*c| {
                c.* = std.ascii.toLower(c.*);
            };
            return .{ .name = name };
        },
        .animation_name => return .{ .name = try names.consumeName(options.allocator, stream) orelse return null },
        .animation_fill_mode => {
            for ([_]values.Keyword{ .forwards, .backwards, .both }) |k| if (ident(stream, k.name())) return .{ .keyword = k };
            return null;
        },
        .animation_range_start, .animation_range_end => {
            const range = names.Range.parse(stream.peek());
            if (range != null) _ = stream.next();
            const offset = try Number.consume(options, stream, .{ .kind = .length_percentage }, true) orelse
                if (range != null) Number.percent(if (l == .animation_range_end) 100 else 0) else return null;
            return .{ .range = .{ .name = range, .offset = offset } };
        },
        .animation_timeline => {
            if (ident(stream, "none")) return .{ .keyword = .none };
            const t = stream.peek();
            if (t.token_type == .ident) {
                _ = stream.next();
                const name = try tokens.decode(options.allocator, t.value);
                if (name.len <= 2 or !std.mem.startsWith(u8, name, "--")) {
                    options.allocator.free(name);
                    return null;
                }
                return .{ .name = name };
            }
            return parseTimeline(options, stream) catch |err| switch (err) {
                error.Invalid => null,
                error.OutOfMemory => error.OutOfMemory,
            };
        },
        else => return null,
    }
}

/// Scroll Animations 1 §§2.2.1,3.3.1,3.4.3: unordered components,
/// with an inseparable one/two-value inset group and per-grammar order.
fn parseTimeline(options: properties.ParseOptions, stream: *Stream) Error!Item {
    const function = stream.next();
    if (function.token_type != .function) return error.Invalid;
    var result = Timeline{ .kind = if (tokens.nameEql(function.value, "scroll")) .scroll else if (tokens.nameEql(function.value, "view")) .view else return error.Invalid };
    errdefer result.release();
    if (stream.next().token_type != .left_paren) return error.Invalid;
    var axis = false;
    var scroller = false;
    var inset = false;
    while (stream.peek().token_type != .right_paren and !stream.atEnd()) {
        const t = stream.peek();
        var matched = false;
        if (!axis and t.token_type == .ident) {
            inline for (@typeInfo(@TypeOf(result.axis)).@"enum".fields) |field| {
                if (tokens.nameEql(t.value, field.name)) {
                    result.axis = @enumFromInt(field.value);
                    axis = true;
                    matched = true;
                }
            }
        }
        if (matched) {
            _ = stream.next();
            continue;
        }
        if (result.kind == .scroll and !scroller and t.token_type == .ident) {
            inline for (@typeInfo(@TypeOf(result.scroller)).@"enum".fields) |field| {
                if (tokens.nameEql(t.value, field.name)) {
                    result.scroller = @enumFromInt(field.value);
                    scroller = true;
                    matched = true;
                }
            }
        }
        if (matched) {
            _ = stream.next();
            continue;
        }
        if (result.kind != .view or inset) return error.Invalid;
        inset = true;
        if (!ident(stream, "auto")) result.insets[0] = try Number.consume(options, stream, .{ .kind = .length_percentage }, true) orelse return error.Invalid;
        if (!ident(stream, "auto")) {
            if (try Number.consume(options, stream, .{ .kind = .length_percentage }, true)) |n| {
                result.insets[1] = n;
            } else {
                result.insets[1] = result.insets[0];
                if (result.insets[1]) |n| n.ref();
            }
        }
    }
    _ = stream.next();
    return .{ .timeline = result };
}

fn isTimeProperty(l: Longhand) bool {
    return l == .animation_delay or l == .transition_duration or l == .transition_delay;
}
fn initialItem(l: Longhand) Item {
    const v = l.info().initial;
    return switch (v) {
        .keyword => |k| .{ .keyword = k },
        .number => |n| .{ .number = if (isTimeProperty(l)) .{ .literal = .{ .value = n, .unit = .s } } else Number.scalar(n) },
        else => unreachable,
    };
}
fn valueCount(v: Value) usize {
    return if (v == .animation_list) v.animation_list.items.items.len else 1;
}
fn valueItem(l: Longhand, v: Value, index: usize) Item {
    return switch (v) {
        .animation_list => |list| list.items.items[index],
        .keyword => |k| .{ .keyword = k },
        .number => |n| .{ .number = if (isTimeProperty(l)) .{ .literal = .{ .value = n, .unit = .s } } else Number.scalar(n) },
        else => unreachable,
    };
}
fn omittedEnd(start: Item) Item {
    if (start == .range and start.range.name != null) return .{ .range = .{ .name = start.range.name, .offset = Number.percent(100) } };
    return .{ .keyword = .normal };
}

/// Animations 1 §4.9: take each token as another component before name.
/// Both time positions are ordered; other components are unordered.
pub fn consumeShorthand(options: properties.ParseOptions, shorthand: properties.Shorthand, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    if (shorthand == .transition) return consumeTransition(options, stream, out);
    const longhands = shorthand.longhands();
    const count: usize = if (shorthand == .animation) 8 else 2;
    var lists: [8]?*List = .{null} ** 8;
    defer for (lists) |list| if (list) |owned| owned.unref();
    for (longhands[0..count], 0..) |l, i| lists[i] = try List.create(options.allocator, l);
    while (true) {
        var items: [8]?Item = .{null} ** 8;
        defer for (items) |item| if (item) |owned| owned.release(options.allocator);
        if (shorthand == .animation_range) {
            items[0] = try consumeItem(options, longhands[0], stream) orelse return false;
            items[1] = try consumeItem(options, longhands[1], stream) orelse omittedEnd(items[0].?);
        } else {
            var consumed: usize = 0;
            while (!stream.atEnd() and stream.peek().token_type != .comma) {
                var found = false;
                for (longhands[0..count], 0..) |l, i| {
                    if (items[i] != null or (i == 2 and items[0] == null)) continue;
                    if (try consumeItem(options, l, stream)) |item| {
                        items[i] = item;
                        found = true;
                        consumed += 1;
                        break;
                    }
                }
                if (!found) return false;
            }
            if (consumed == 0) return false;
        }
        for (longhands[0..count], 0..) |l, i| {
            const item = items[i] orelse initialItem(l);
            items[i] = null;
            try lists[i].?.append(item);
        }
        if (stream.atEnd()) break;
        if (stream.next().token_type != .comma) return false;
    }
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands[0..count], 0..) |l, i| {
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = .{ .animation_list = lists[i].? } } });
        lists[i] = null;
    }
    // Q69: reset each field once, independent of the number of animations.
    for (longhands[count..]) |l| out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = l.info().initial } });
    return true;
}

pub fn serializeDurationResolved(duration: Value, timeline: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const automatic = valueCount(timeline) == 1 and valueItem(.animation_timeline, timeline, 0).isKeyword(.auto);
    for (0..valueCount(duration)) |i| {
        if (i > 0) try out.appendSlice(allocator, ", ");
        const item = valueItem(.animation_duration, duration, i);
        if (automatic and item.isKeyword(.auto)) try out.appendSlice(allocator, "0s") else try item.serialize(.animation_duration, out, allocator);
    }
}

pub fn serializeShorthand(shorthand: properties.Shorthand, assigned: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (shorthand == .transition) return serializeTransition(assigned, mode, out, allocator);
    const longhands = shorthand.longhands();
    const count: usize = if (shorthand == .animation) 8 else 2;
    const length = valueCount(assigned[0].value);
    for (assigned[1..count]) |v| if (valueCount(v.value) != length) return false;
    for (longhands[count..], assigned[count..]) |l, v| {
        if (valueCount(v.value) != 1 or !valueItem(l, v.value, 0).eql(initialItem(l))) return false;
    }
    for (0..length) |index| {
        if (index > 0) try out.appendSlice(allocator, ", ");
        if (shorthand == .animation_range) {
            const start = valueItem(longhands[0], assigned[0].value, index);
            const end = valueItem(longhands[1], assigned[1].value, index);
            try start.serialize(longhands[0], out, allocator);
            const omit = end.eql(omittedEnd(start)) or (start == .range and start.range.name == null and end == .range and end.range.name == null and defaultOffset(end.range.offset, true));
            if (!omit) {
                try out.append(allocator, ' ');
                try end.serialize(longhands[1], out, allocator);
            }
            continue;
        }
        var items: [8]Item = undefined;
        var include: [8]bool = undefined;
        for (longhands[0..count], 0..) |l, i| {
            items[i] = valueItem(l, assigned[i].value, index);
            include[i] = !isInitial(items[i], l);
        }
        // A name also accepted by another component must be disambiguated
        // by serializing that component, even when it has its initial value.
        if (items[7] == .name) {
            for (longhands[0..7], 0..) |l, i| {
                var stream = Stream.init(items[7].name);
                if (try consumeItem(.{ .allocator = allocator }, l, &stream)) |parsed| {
                    defer parsed.release(allocator);
                    if (stream.atEnd()) include[i] = true;
                }
            }
        }
        if (include[2]) include[0] = true;
        var wrote = false;
        for (longhands[0..count], 0..) |l, i| {
            if (!include[i]) continue;
            if (wrote) try out.append(allocator, ' ');
            if (mode == .computed and i == 0 and items[i].isKeyword(.auto)) {
                try out.appendSlice(allocator, "0s");
            } else try items[i].serialize(l, out, allocator);
            wrote = true;
        }
        if (!wrote) try out.appendSlice(allocator, "none");
    }
    return true;
}

fn isInitial(item: Item, l: Longhand) bool {
    if (item.eql(initialItem(l))) return true;
    // The shorthand's omitted duration has the legacy 0s serialization;
    // the longhand's computed auto is kept until resolved-value access.
    if (l == .animation_duration and item == .number and item.number == .literal and item.number.literal.value == 0) return true;
    if ((l == .animation_timing_function or l == .transition_timing_function) and item == .easing and item.easing.kind == .keyword and std.mem.eql(u8, item.easing.keyword, "ease")) return true;
    return false;
}

/// Transitions 1 §2.5 / Transitions 2 §2.6: duration precedes delay;
/// consume all the other grammar components before the property identifier.
fn consumeTransition(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    const longhands = properties.Shorthand.transition.longhands();
    var lists: [5]?*List = .{null} ** 5;
    defer for (lists) |list| if (list) |owned| owned.unref();
    for (longhands, 0..) |longhand, index| lists[index] = try List.create(options.allocator, longhand);
    while (true) {
        var items: [5]?Item = .{null} ** 5;
        defer for (items) |item| if (item) |owned| owned.release(options.allocator);
        var consumed: usize = 0;
        while (!stream.atEnd() and stream.peek().token_type != .comma) {
            var found = false;
            // Canonical output order is property, duration, easing, delay,
            // behavior. Parsing reserves property-like keywords for the other
            // components first, and a first negative time is never a delay.
            for ([_]usize{ 1, 2, 3, 4, 0 }) |index| {
                if (items[index] != null or (index == 3 and items[1] == null)) continue;
                if (try consumeItem(options, longhands[index], stream)) |item| {
                    items[index] = item;
                    found = true;
                    consumed += 1;
                    break;
                }
            }
            if (!found) return false;
        }
        if (consumed == 0) return false;
        for (longhands, 0..) |longhand, index| {
            const item = items[index] orelse initialItem(longhand);
            items[index] = null;
            try lists[index].?.append(item);
        }
        if (stream.atEnd()) break;
        if (stream.next().token_type != .comma) return false;
    }
    if (!lists[0].?.validTransitionProperties()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, 0..) |longhand, index| {
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = .{ .animation_list = lists[index].? } } });
        lists[index] = null;
    }
    return true;
}

fn serializeTransition(assigned: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const longhands = properties.Shorthand.transition.longhands();
    var length = valueCount(assigned[0].value);
    if (mode != .computed) {
        // Q85: all five declared longhands must be present (the caller's
        // contract); unequal lists serialize their existing entries only.
        for (assigned[1..]) |value| length = @max(length, valueCount(value.value));
    }
    for (0..length) |index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        var items: [5]Item = undefined;
        var include: [5]bool = undefined;
        for (longhands, 0..) |longhand, component| {
            const count = valueCount(assigned[component].value);
            // Transitions1 §2, Q89: computed serialization follows the
            // property-list length, repeating shorter ancillary lists and
            // ignoring their excess entries. Declared lists retain omissions.
            const present = mode == .computed or index < count;
            items[component] = if (present) valueItem(longhand, assigned[component].value, if (mode == .computed) index % count else index) else initialItem(longhand);
            include[component] = present and !isInitial(items[component], longhand);
        }
        if (length > 1 and items[0].isKeyword(.none)) return false;
        // Q85: the three-browser majority omits initial components even
        // for keyword-like property names, despite reparse-role changes.
        // Q86: computed serialization keeps 0s before a nonzero delay;
        // declared serialization omits it (Chrome/Safari majority).
        if (mode == .computed and include[3]) include[1] = true;
        var wrote = false;
        for (longhands, 0..) |longhand, component| {
            if (!include[component]) continue;
            if (wrote) try out.append(allocator, ' ');
            try items[component].serialize(longhand, out, allocator);
            wrote = true;
        }
        if (!wrote) try out.appendSlice(allocator, "all");
    }
    return true;
}
