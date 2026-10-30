//! CSS Text Decoration 3 §4: owned shadow lists. Decor4 inset/spread are
//! deliberately excluded: pinned WPT and all three browsers reject them.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Color = values.Color;
const Stream = properties.Stream;

const Shadow = struct {
    color: ?Color = null,
    lengths: [3]Value = @splat(Value.px(0)),
    count: u2 = 0,

    fn retain(self: Shadow) void {
        if (self.color) |color| color.retain();
        for (self.lengths[0..self.count]) |length| length.retain();
    }
    fn release(self: Shadow) void {
        if (self.color) |color| color.release();
        for (self.lengths[0..self.count]) |length| length.release();
    }
    fn eql(self: Shadow, other: Shadow) bool {
        if (self.count != other.count) return false;
        if (self.color) |color| {
            if (!color.eql(other.color orelse return false)) return false;
        } else if (other.color != null) return false;
        for (self.lengths[0..self.count], other.lengths[0..other.count]) |a, b| if (!a.eql(b)) return false;
        return true;
    }
};

pub const Shadows = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    items: []const Shadow,
    computed: bool,

    fn create(allocator: Allocator, items: []const Shadow, computed: bool) Allocator.Error!*Shadows {
        const owned = try allocator.dupe(Shadow, items);
        errdefer allocator.free(owned);
        const self = try allocator.create(Shadows);
        self.* = .{ .allocator = allocator, .items = owned, .computed = computed };
        for (owned) |item| item.retain();
        return self;
    }
    pub fn ref(self: *Shadows) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Shadows) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| item.release();
        self.allocator.free(self.items);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Shadows, other: *const Shadows) bool {
        if (self == other) return true;
        if (self.computed != other.computed or self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const Shadows, geometry_length: bool) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsUnavailableMetrics(geometry_length)) return true;
            for (item.lengths[0..item.count]) |length| if (length.needsUnavailableMetrics(geometry_length)) return true;
        }
        return false;
    }
    pub fn needsTreeCounts(self: *const Shadows) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsTreeCounts()) return true;
            for (item.lengths[0..item.count]) |length| if (length.needsTreeCounts()) return true;
        }
        return false;
    }
    pub fn needsRandomBase(self: *const Shadows) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsRandomBase()) return true;
            for (item.lengths[0..item.count]) |length| if (length.needsRandomBase()) return true;
        }
        return false;
    }
    pub fn serialize(self: *const Shadows, current: ?Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items, 0..) |item, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            if (item.color) |color| {
                if (current) |receiver| {
                    const resolved = try color.resolveComputed(allocator, .{ .current = receiver });
                    defer resolved.release();
                    try resolved.serializeComputed(out, allocator);
                } else if (self.computed) try color.serializeComputed(out, allocator) else try color.serializeSpecified(out, allocator);
                try out.append(allocator, ' ');
            }
            for (item.lengths[0..item.count], 0..) |length, j| {
                if (j != 0) try out.append(allocator, ' ');
                try properties.serializeValue(.text_shadow, length, out, allocator);
            }
        }
    }
    pub fn compute(self: *const Shadows, allocator: Allocator, context: anytype) Allocator.Error!*Shadows {
        // Blink ConvertShadow retains StyleColor; ValueForShadowData resolves
        // currentcolor against the receiver. Inheritance must preserve it.
        var result: std.ArrayList(Shadow) = .empty;
        defer {
            for (result.items) |item| item.release();
            result.deinit(allocator);
        }
        for (self.items) |item| {
            var computed = Shadow{};
            errdefer computed.release();
            computed.color = try context.color(item.color orelse .current);
            for (item.lengths) |length| {
                computed.lengths[computed.count] = try context.length(length);
                computed.count += 1;
            }
            try result.append(allocator, computed);
        }
        return create(allocator, result.items, true);
    }
};

fn consumeColor(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Color {
    const start = stream.*;
    const parsed = try properties.parseLonghand(options, .text_decoration_color, stream) orelse {
        stream.* = start;
        return null;
    };
    return parsed.color;
}

fn consumeLength(options: properties.ParseOptions, stream: *Stream, nonnegative: bool) Allocator.Error!?Value {
    const start = stream.*;
    const number = try Number.consume(options, stream, .{
        .kind = .length,
        .minimum = if (nonnegative) 0 else -std.math.floatMax(f64),
    }, true) orelse {
        stream.* = start;
        return null;
    };
    return switch (number) {
        .calculation => |expression| .{ .calculation = expression },
        .literal => |literal| .{ .length = .{ .value = literal.value, .unit = values.LengthUnit.fromString(literal.unit.name()).? } },
    };
}

fn shadow(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Shadow {
    var result = Shadow{};
    var moved = false;
    defer if (!moved) result.release();
    result.color = try consumeColor(options, stream);
    while (result.count < 3) {
        result.lengths[result.count] = try consumeLength(options, stream, result.count == 2) orelse break;
        result.count += 1;
    }
    if (result.count < 2) return null;
    if (result.color == null) result.color = try consumeColor(options, stream);
    moved = true;
    return result;
}

pub fn parse(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (stream.peek().token_type == .ident and tokens.nameEql(stream.peek().value, "none")) {
        _ = stream.next();
        return Value.kw(.none);
    }
    var items: std.ArrayList(Shadow) = .empty;
    defer {
        for (items.items) |item| item.release();
        items.deinit(options.allocator);
    }
    while (true) {
        const item = try shadow(options, stream) orelse return null;
        errdefer item.release();
        try items.append(options.allocator, item);
        if (stream.atEnd()) break;
        if (stream.next().token_type != .comma) return null;
    }
    return .{ .text_shadow = try Shadows.create(options.allocator, items.items, false) };
}
