//! Filter Effects 1 §5–6: owned typed functions and reference ordering.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const paint = @import("svg_paint.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Color = values.Color;

pub const Kind = enum {
    blur,
    brightness,
    contrast,
    drop_shadow,
    grayscale,
    hue_rotate,
    invert,
    opacity,
    sepia,
    saturate,

    fn name(self: Kind) []const u8 {
        return switch (self) {
            .drop_shadow => "drop-shadow",
            .hue_rotate => "hue-rotate",
            inline else => |k| @tagName(k),
        };
    }
    fn parse(t: tokenizer.Token) ?Kind {
        if (t.token_type != .function) return null;
        inline for (@typeInfo(Kind).@"enum".fields) |f| {
            const k: Kind = @enumFromInt(f.value);
            if (tokenizer.nameEql(t.value, k.name())) return k;
        }
        return null;
    }
    fn clamps(self: Kind) bool {
        return switch (self) {
            .grayscale, .invert, .opacity, .sepia => true,
            else => false,
        };
    }
};

pub const Angle = @import("image_angle.zig").Angle;
pub const Shadow = struct { color: ?Color = null, lengths: [3]Value, count: u2 };
pub const Function = struct {
    kind: Kind,
    argument: union(enum) { omitted, scalar: Value, angle: Angle, shadow: Shadow },

    fn release(self: Function) void {
        switch (self.argument) {
            .scalar => |v| v.release(),
            .shadow => |s| {
                if (s.color) |c| c.release();
                for (s.lengths[0..s.count]) |v| v.release();
            },
            else => {},
        }
    }
    fn retain(self: Function) void {
        switch (self.argument) {
            .scalar => |v| v.retain(),
            .shadow => |s| {
                if (s.color) |c| c.retain();
                for (s.lengths[0..s.count]) |v| v.retain();
            },
            else => {},
        }
    }
    fn serialize(self: Function, out: *std.ArrayList(u8), allocator: Allocator, computed: bool, current: ?Color) Allocator.Error!void {
        try out.appendSlice(allocator, self.kind.name());
        try out.append(allocator, '(');
        switch (self.argument) {
            .omitted => {},
            .scalar => |v| try properties.serializeValue(.margin_left, v, out, allocator),
            .angle => |a| {
                try values.appendNumber(a.number, out, allocator);
                try out.appendSlice(allocator, @tagName(a.unit));
            },
            .shadow => |s| {
                if (s.color) |c| {
                    if (current) |receiver_color| {
                        const resolved = try c.resolveComputed(allocator, .{ .current = receiver_color });
                        defer resolved.release();
                        try resolved.serializeComputed(out, allocator);
                    } else if (computed) try c.serializeComputed(out, allocator) else try c.serializeSpecified(out, allocator);
                    try out.append(allocator, ' ');
                }
                for (s.lengths[0..s.count], 0..) |v, i| {
                    if (i > 0) try out.append(allocator, ' ');
                    try properties.serializeValue(.margin_left, v, out, allocator);
                }
            },
        }
        try out.append(allocator, ')');
    }
};
pub const Item = union(enum) {
    reference: Value,
    function: Function,

    fn release(self: Item) void {
        switch (self) {
            .reference => |v| v.release(),
            .function => |f| f.release(),
        }
    }
    fn retain(self: Item) void {
        switch (self) {
            .reference => |v| v.retain(),
            .function => |f| f.retain(),
        }
    }
};

pub const Filter = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    items: []const Item,
    text: *values.SharedText,

    pub fn ref(self: *Filter) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Filter) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| item.release();
        self.allocator.free(self.items);
        self.text.unref();
        self.allocator.destroy(self);
    }
    pub fn needsTreeCounts(self: *const Filter) bool {
        for (self.items) |item| switch (item) {
            .reference => {},
            .function => |function| switch (function.argument) {
                .omitted, .angle => {},
                .scalar => |value| if (value.needsTreeCounts()) return true,
                .shadow => |shadow| {
                    if (shadow.color) |color| if (color.needsTreeCounts()) return true;
                    for (shadow.lengths[0..shadow.count]) |value| if (value.needsTreeCounts()) return true;
                },
            },
        };
        return false;
    }
    pub fn needsRandomBase(self: *const Filter) bool {
        for (self.items) |item| switch (item) {
            .reference => {},
            .function => |function| switch (function.argument) {
                .omitted, .angle => {},
                .scalar => |value| if (value.needsRandomBase()) return true,
                .shadow => |shadow| {
                    if (shadow.color) |color| if (color.needsRandomBase()) return true;
                    for (shadow.lengths[0..shadow.count]) |value| if (value.needsRandomBase()) return true;
                },
            },
        };
        return false;
    }
    pub fn needsUnavailableMetrics(self: *const Filter, geometry_length: bool) bool {
        for (self.items) |item| switch (item) {
            .reference => {},
            .function => |function| switch (function.argument) {
                .omitted, .angle => {},
                .scalar => |value| if (value.needsUnavailableMetrics(geometry_length)) return true,
                .shadow => |shadow| {
                    if (shadow.color) |color| if (color.needsUnavailableMetrics(geometry_length)) return true;
                    for (shadow.lengths[0..shadow.count]) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
                },
            },
        };
        return false;
    }

    pub fn eql(self: *const Filter, other: *const Filter) bool {
        return self == other or std.mem.eql(u8, self.text.bytes, other.text.bytes);
    }

    /// Retains borrowed input components; its text and URL ranges agree.
    pub fn create(allocator: Allocator, items: []const Item) Allocator.Error!*Filter {
        return createInternal(allocator, items, false);
    }

    fn createInternal(allocator: Allocator, items: []const Item, computed: bool) Allocator.Error!*Filter {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        var urls = resources.Builder{ .allocator = allocator };
        defer urls.deinit();
        for (items, 0..) |item, i| {
            if (i > 0) try out.append(allocator, ' ');
            switch (item) {
                .reference => |v| {
                    try urls.append(v.resourceUrls(), out.items.len);
                    try properties.serializeValue(.list_style_image, v, &out, allocator);
                },
                .function => |f| try f.serialize(&out, allocator, computed, null),
            }
        }
        const text = try values.SharedText.create(allocator, out.items);
        errdefer text.unref();
        text.resource_urls = try urls.take();
        const owned = try allocator.dupe(Item, items);
        errdefer allocator.free(owned);
        const self = try allocator.create(Filter);
        self.* = .{ .allocator = allocator, .items = owned, .text = text };
        for (owned) |item| item.retain();
        return self;
    }

    /// CSSOM resolves the receiver's currentcolor only when exposing this
    /// computed filter. The immutable value and its URL ranges stay unchanged.
    /// Design: Blink ConvertShadow preserves StyleColor; ValueForShadowData
    /// resolves it against the receiving style (drop-shadow inheritance WPT).
    pub fn serializeResolved(self: *const Filter, current: Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items, 0..) |item, index| {
            if (index != 0) try out.append(allocator, ' ');
            switch (item) {
                .reference => |value| try @import("resolved_urls.zig").serialize(.list_style_image, value, out, allocator),
                .function => |function| try function.serialize(out, allocator, true, current),
            }
        }
    }

    /// §6.2: defaults become explicit, lengths absolute, percentages numbers.
    /// Context uses the cascade's component conversion, preserving symbolic
    /// currentcolor for inheritance. It is borrowed and never retained.
    pub fn compute(self: *const Filter, allocator: Allocator, context: anytype) Allocator.Error!*Filter {
        var items: std.ArrayList(Item) = .empty;
        defer {
            for (items.items) |item| item.release();
            items.deinit(allocator);
        }
        for (self.items) |item| {
            const computed = switch (item) {
                .reference => blk: {
                    item.retain();
                    break :blk item;
                },
                .function => |f| Item{ .function = try computeFunction(f, context) },
            };
            errdefer computed.release();
            try items.append(allocator, computed);
        }
        return createInternal(allocator, items.items, true);
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    // Filter components do not inherit color/margin parser quirks.
    var strict = options;
    strict.quirks = false;
    if (stream.peek().token_type == .ident and tokenizer.nameEql(stream.peek().value, "none")) {
        _ = stream.next();
        return Value.kw(.none);
    }
    var items: std.ArrayList(Item) = .empty;
    defer {
        for (items.items) |item| item.release();
        items.deinit(options.allocator);
    }
    while (true) {
        const item: Item = if (paint.isUrl(stream.peek())) blk: {
            break :blk .{ .reference = (try paint.parseReference(strict, stream)) orelse return null };
        } else if (Kind.parse(stream.peek())) |kind| blk: {
            _ = stream.next();
            if (stream.next().token_type != .left_paren) return null;
            const f = (try parseFunction(strict, stream, kind)) orelse return null;
            if (stream.next().token_type != .right_paren) {
                f.release();
                return null;
            }
            break :blk .{ .function = f };
        } else break;
        errdefer item.release();
        try items.append(options.allocator, item);
    }
    if (items.items.len == 0) return null;
    return .{ .filter = try Filter.create(options.allocator, items.items) };
}

fn parseFunction(options: properties.ParseOptions, stream: *properties.Stream, kind: Kind) Allocator.Error!?Function {
    if (stream.peek().token_type == .right_paren) return if (kind == .drop_shadow) null else .{ .kind = kind, .argument = .omitted };
    if (kind == .drop_shadow) return parseShadow(options, stream);
    if (kind == .hue_rotate) return .{ .kind = kind, .argument = .{ .angle = @import("image_angle.zig").parse(stream, true) orelse return null } };
    if (kind == .blur) return .{ .kind = kind, .argument = .{ .scalar = (try parseLength(options, stream, false)) orelse return null } };
    const t = stream.next();
    if (t.token_type != .number and t.token_type != .percentage) return null;
    const n = t.numeric_value orelse return null;
    if (n < 0) return null;
    const number = if (kind.clamps()) @min(n, if (t.token_type == .percentage) @as(f64, 100) else 1) else n;
    return .{ .kind = kind, .argument = .{ .scalar = if (t.token_type == .percentage) .{ .length = .percent(number) } else .{ .number = number } } };
}

fn parseLength(options: properties.ParseOptions, stream: *properties.Stream, negative: bool) Allocator.Error!?Value {
    const v = (try properties.parseLonghand(options, .margin_left, stream)) orelse return null;
    if (v != .length or v.length.unit == .percent or (!negative and v.length.value < 0)) {
        v.release();
        return null;
    }
    return v;
}

fn parseShadow(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Function {
    var s = Shadow{ .lengths = undefined, .count = 0 };
    var moved = false;
    defer if (!moved) {
        if (s.color) |c| c.release();
        for (s.lengths[0..s.count]) |v| v.release();
    };
    const start = stream.*;
    s.color = try parseShadowColor(options, stream);
    if (s.color == null) stream.* = start;
    while (s.count < 3) {
        const mark = stream.*;
        const v = try parseLength(options, stream, s.count < 2) orelse {
            stream.* = mark;
            break;
        };
        s.lengths[s.count] = v;
        s.count += 1;
    }
    if (s.count < 2) return null;
    if (s.color == null) s.color = try parseShadowColor(options, stream);
    moved = true;
    return .{ .kind = .drop_shadow, .argument = .{ .shadow = s } };
}

fn parseShadowColor(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Color {
    const value = (try properties.parseLonghand(options, .color, stream)) orelse return null;
    defer value.release();
    std.debug.assert(value == .color);
    value.color.retain();
    return value.color;
}

fn computeFunction(f: Function, context: anytype) Allocator.Error!Function {
    const argument: @FieldType(Function, "argument") = switch (f.argument) {
        .omitted => switch (f.kind) {
            .blur => .{ .scalar = Value.px(0) },
            .hue_rotate => .{ .angle = .{ .number = 0, .unit = .deg } },
            else => .{ .scalar = .{ .number = 1 } },
        },
        .angle => |a| .{ .angle = .{ .number = a.degrees(), .unit = .deg } },
        .scalar => |v| blk: {
            if (f.kind == .blur) break :blk .{ .scalar = try context.length(v) };
            const n = if (v == .number) v.number else v.length.value / 100;
            break :blk .{ .scalar = .{ .number = if (f.kind.clamps()) @min(n, 1) else n } };
        },
        .shadow => |s| blk: {
            var result = Shadow{ .lengths = undefined, .count = 0 };
            errdefer {
                if (result.color) |c| c.release();
                for (result.lengths[0..result.count]) |v| v.release();
            }
            result.color = try context.color(s.color orelse .current);
            while (result.count < 3) : (result.count += 1) result.lengths[result.count] = try context.length(if (result.count < s.count) s.lengths[result.count] else Value.px(0));
            break :blk .{ .shadow = result };
        },
    };
    return .{ .kind = f.kind, .argument = argument };
}
