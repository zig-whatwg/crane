//! CSS Typed OM 1 §4.3.1: algebra over live reified objects, no CSS parser.
const std = @import("std");
const math = @import("../math_values.zig");
const numeric = @import("numeric.zig");
const Allocator = std.mem.Allocator;
pub const Kind = enum { unit, sum, product, negate, invert, min, max, clamp };
pub const View = struct { kind: Kind, number: math.Numeric = .{ .value = 0, .unit = .number }, count: usize = 0 };
const unit_count = @typeInfo(math.Unit).@"enum".field_names.len;
pub const Term = struct {
    value: f64,
    units: [unit_count]i32 = @splat(0),

    fn from(number: math.Numeric) Term {
        var result: Term = .{ .value = number.value };
        var unit = number.unit;
        if (unit.absoluteScale()) |scale| {
            result.value *= scale;
            unit = unit.canonical();
        }
        if (unit != .number) result.units[@intFromEnum(unit)] = 1;
        return result;
    }

    /// Create a CSSUnitValue from a sum-value item, steps 1–3.
    pub fn asNumeric(self: Term) error{Invalid}!math.Numeric {
        var unit: math.Unit = .number;
        for (self.units, 0..) |power, index| {
            if (power == 0) continue;
            if (power != 1 or unit != .number) return error.Invalid;
            unit = @enumFromInt(index);
        }
        return .{ .value = self.value, .unit = unit };
    }

    fn sameUnits(a: Term, b: Term) bool {
        return std.mem.eql(i32, &a.units, &b.units);
    }
};
pub const Sum = std.ArrayList(Term);

/// Compatibility is identity or an existing absolute-unit conversion.
/// Relative lengths never acquire a context from a bare NumericValue.
pub fn convert(number: math.Numeric, unit: math.Unit) error{Invalid}!math.Numeric {
    if (number.unit == unit) return number;
    if (number.unit.base() != unit.base()) return error.Invalid;
    const from = number.unit.absoluteScale() orelse return error.Invalid;
    const to = unit.absoluteScale() orelse return error.Invalid;
    return .{ .value = number.value * from / to, .unit = unit };
}

fn merge(allocator: Allocator, sum: *Sum, item: Term) !void {
    for (sum.items) |*existing| if (existing.sameUnits(item)) {
        existing.value += item.value;
        return;
    };
    try sum.append(allocator, item);
}

fn typeOf(item: Term) error{Invalid}!math.Type {
    var result: math.Type = .{};
    for (item.units, 0..) |power, index| {
        if (power == 0) continue;
        const unit: math.Unit = @enumFromInt(index);
        const base = unit.base() orelse continue;
        const b = @intFromEnum(base);
        result.powers[b] +%= power;
    }
    return result;
}

fn combine(allocator: Allocator, kind: Kind, children: []const Sum) !Sum {
    var out: Sum = .empty;
    errdefer out.deinit(allocator);
    switch (kind) {
        .unit => unreachable,
        .sum => {
            for (children) |child| for (child.items) |item| try merge(allocator, &out, item);
            var typ: ?math.Type = null;
            for (out.items) |item| {
                const next = try typeOf(item);
                typ = if (typ) |t| try numeric.addTypes(t, next) else next;
            }
        },
        .negate, .invert => {
            try out.appendSlice(allocator, children[0].items);
            if (kind == .invert) {
                if (out.items.len != 1) return error.Invalid;
                out.items[0].value = 1 / out.items[0].value;
                for (&out.items[0].units) |*power| power.* = 0 -% power.*;
            } else for (out.items) |*item| item.value = -item.value;
        },
        .product => {
            try out.append(allocator, .{ .value = 1 });
            for (children) |child| {
                var next: Sum = .empty;
                errdefer next.deinit(allocator);
                for (out.items) |a| for (child.items) |b| {
                    var item: Term = .{ .value = a.value * b.value };
                    for (&item.units, a.units, b.units) |*power, x, y| power.* = x +% y;
                    try next.append(allocator, item);
                };
                out.deinit(allocator);
                out = next;
            }
        },
        .min, .max, .clamp => {
            if (children.len == 0 or children[0].items.len != 1) return error.Invalid;
            var chosen = children[0].items[0];
            for (children) |child| if (child.items.len != 1 or !chosen.sameUnits(child.items[0])) return error.Invalid;
            if (kind == .clamp) {
                if (children.len != 3) return error.Invalid;
                chosen.value = maximum(chosen.value, minimum(children[1].items[0].value, children[2].items[0].value));
            } else {
                for (children[1..]) |child| chosen.value = if (kind == .min) minimum(chosen.value, child.items[0].value) else maximum(chosen.value, child.items[0].value);
            }
            try out.append(allocator, chosen);
        },
    }
    return out;
}

pub fn minimum(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a) or std.math.signbit(b)) -@as(f64, 0) else 0;
    return @min(a, b);
}
pub fn maximum(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a) and std.math.signbit(b)) -@as(f64, 0) else 0;
    return @max(a, b);
}

/// Create a sum value, §4.3.1: postorder traversal with owned temporary
/// lists. Reader.view(id) and child(id,index) borrow immutable graph links;
/// leaf values remain live and are read anew on every operation.
pub fn sumValue(allocator: Allocator, root: usize, reader: anytype) !Sum {
    const Frame = struct { id: usize, view: View, index: usize = 0, base: usize };
    var frames: std.ArrayList(Frame) = .empty;
    defer frames.deinit(allocator);
    var sums: std.ArrayList(Sum) = .empty;
    defer {
        for (sums.items) |*sum| sum.deinit(allocator);
        sums.deinit(allocator);
    }
    try frames.append(allocator, .{ .id = root, .view = try reader.view(root), .base = 0 });
    while (frames.items.len != 0) {
        const frame = &frames.items[frames.items.len - 1];
        if (frame.index < frame.view.count) {
            const child = try reader.child(frame.id, frame.index);
            frame.index += 1;
            try frames.append(allocator, .{ .id = child, .view = try reader.view(child), .base = sums.items.len });
            continue;
        }
        var result: Sum = if (frame.view.kind == .unit) blk: {
            var one: Sum = .empty;
            try one.append(allocator, Term.from(frame.view.number));
            break :blk one;
        } else try combine(allocator, frame.view.kind, sums.items[frame.base..]);
        errdefer result.deinit(allocator);
        for (sums.items[frame.base..]) |*sum| sum.deinit(allocator);
        sums.shrinkRetainingCapacity(frame.base);
        try sums.append(allocator, result);
        _ = frames.pop();
    }
    return sums.pop().?;
}

/// Equal numeric values, steps 1–5: exact structure, order, unit and value.
/// A stack handles arbitrarily deep immutable math graphs without recursion.
pub fn equals(allocator: Allocator, lhs: usize, rhs: usize, reader: anytype) !bool {
    const Pair = struct { a: usize, b: usize };
    var pairs: std.ArrayList(Pair) = .empty;
    defer pairs.deinit(allocator);
    try pairs.append(allocator, .{ .a = lhs, .b = rhs });
    while (pairs.pop()) |pair| {
        const a = try reader.view(pair.a);
        const b = try reader.view(pair.b);
        if (a.kind != b.kind or a.count != b.count) return false;
        if (a.kind == .unit) {
            if (a.number.unit != b.number.unit or a.number.value != b.number.value) return false;
        } else for (0..a.count) |index| try pairs.append(allocator, .{
            .a = try reader.child(pair.a, index),
            .b = try reader.child(pair.b, index),
        });
    }
    return true;
}

/// Typed OM §6.5, preserving constructor structure and child order.
/// The caller owns the returned string; all traversal memory is call-local.
pub fn serialize(allocator: Allocator, root: usize, reader: anytype) ![]u8 {
    const Frame = struct {
        id: usize,
        view: View,
        index: usize = 0,
        nested: bool = false,
        paren_less: bool = false,
        started: bool = false,
    };
    var frames: std.ArrayList(Frame) = .empty;
    defer frames.deinit(allocator);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try frames.append(allocator, .{ .id = root, .view = try reader.view(root) });
    while (frames.items.len != 0) {
        const frame = &frames.items[frames.items.len - 1];
        const kind = frame.view.kind;
        if (kind == .unit) {
            try @import("../style_values.zig").appendNumber(frame.view.number.value, &out, allocator);
            try out.appendSlice(allocator, frame.view.number.unit.name());
            _ = frames.pop();
            continue;
        }
        const function = kind == .min or kind == .max or kind == .clamp;
        if (!frame.started) {
            if (function) {
                try out.appendSlice(allocator, @tagName(kind));
                try out.append(allocator, '(');
            } else if (!frame.paren_less) try out.appendSlice(allocator, if (frame.nested) "(" else "calc(");
            if (kind == .negate) try out.append(allocator, '-');
            if (kind == .invert) try out.appendSlice(allocator, "1 / ");
            frame.started = true;
        }
        if (frame.index == frame.view.count) {
            if (function or !frame.paren_less) try out.append(allocator, ')');
            _ = frames.pop();
            continue;
        }
        var child = try reader.child(frame.id, frame.index);
        var child_view = try reader.view(child);
        if (frame.index != 0) {
            if (function) {
                try out.appendSlice(allocator, ", ");
            } else if (kind == .sum or kind == .product) {
                const inverse = child_view.kind == (if (kind == .sum) Kind.negate else Kind.invert);
                try out.appendSlice(allocator, if (kind == .sum) (if (inverse) " - " else " + ") else (if (inverse) " / " else " * "));
                if (inverse) {
                    child = try reader.child(child, 0);
                    child_view = try reader.view(child);
                }
            }
        }
        frame.index += 1;
        try frames.append(allocator, .{ .id = child, .view = child_view, .nested = true, .paren_less = function });
    }
    return out.toOwnedSlice(allocator);
}

/// A view of an ALREADY PARSED calculation; no tokenization or reparsing.
/// Chrome/Safari Q21 put a product's scalar coefficient after unresolved
/// factors when reifying it. Constructor graphs keep their input order.
pub const ParsedReader = struct {
    /// Typed OM §5.2 step 1: a valid property tree with an operation outside
    /// §5.6's hierarchy keeps its associated native CSSStyleValue (Q95,
    /// Chrome156 probe and Blink StyleValueFactory's unsupported fallback).
    /// Check descendants before allocating wrappers, using view's allowlist.
    /// These are already bounded native property trees, never JS graphs.
    pub fn supports(node: *const math.Node) bool {
        const reader: @This() = .{};
        _ = reader.view(@intFromPtr(node)) catch return false;
        for (node.children) |child_node| if (!supports(child_node)) return false;
        return true;
    }

    pub fn view(_: @This(), id: usize) error{Invalid}!View {
        const node: *const math.Node = @ptrFromInt(id);
        return .{ .kind = switch (node.tag) {
            .numeric => .unit,
            .sum => .sum,
            .product => .product,
            .negate => .negate,
            .invert => .invert,
            .min => .min,
            .max => .max,
            .clamp => .clamp,
            else => return error.Invalid,
        }, .number = node.numeric, .count = node.children.len };
    }

    pub fn child(_: @This(), id: usize, index: usize) error{Invalid}!usize {
        const node: *const math.Node = @ptrFromInt(id);
        if (index >= node.children.len) return error.Invalid;
        if (node.tag != .product) return @intFromPtr(node.children[index]);
        var wanted = index;
        for (node.children) |item| {
            if (item.tag == .numeric and item.numeric.unit == .number) continue;
            if (wanted == 0) return @intFromPtr(item);
            wanted -= 1;
        }
        for (node.children) |item| {
            if (item.tag != .numeric or item.numeric.unit != .number) continue;
            if (wanted == 0) return @intFromPtr(item);
            wanted -= 1;
        }
        return error.Invalid;
    }
};
