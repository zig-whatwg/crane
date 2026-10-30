//! CSS Typed OM §§4.3.1–2, 6.5: type algebra, conversion, and graph operations.
const std = @import("std");
const css = @import("css");
const allocator = std.testing.allocator;

test "unhinted percentage addition searches every dimension and preserves hint conflicts" {
    if (comptime !@hasDecl(css.typed_om.numeric, "addTypes")) return std.testing.expect(false);
    const numeric = css.typed_om.numeric;
    const Type = css.math_values.Type;
    const Base = css.math_values.Base;
    for ([_]Base{ .length, .angle, .time, .frequency, .resolution, .flex }) |base| {
        const result = try numeric.addTypes(Type.one(base), Type.one(.percent));
        try std.testing.expectEqual(base, result.hint.?);
        try std.testing.expectEqual(@as(i32, 1), result.powers[@intFromEnum(base)]);
        try std.testing.expectEqual(@as(i32, 0), result.powers[@intFromEnum(Base.percent)]);
    }
    try std.testing.expectError(error.Invalid, numeric.addTypes(Type.one(null), Type.one(.percent)));
    try std.testing.expectError(error.Invalid, numeric.addTypes(Type.one(.length), Type.one(.angle)));
    const a = try numeric.addTypes(Type.one(.length), Type.one(.percent));
    const b = try numeric.addTypes(Type.one(.angle), Type.one(.percent));
    try std.testing.expectError(error.Invalid, numeric.addTypes(a, b));
    try std.testing.expectError(error.Invalid, numeric.multiplyTypes(a, b));
    var squared = Type.one(.length);
    squared.powers[0] = 2;
    var mixed = Type.one(.length);
    mixed.powers[@intFromEnum(Base.percent)] = 1;
    const square_sum = try numeric.addTypes(squared, mixed);
    try std.testing.expectEqual(@as(i32, 2), square_sum.powers[0]);
    try std.testing.expectEqual(Base.length, square_sum.hint.?);
}

test "Q84 numeric type exponents wrap at the full WebIDL long boundary" {
    if (comptime !@hasDecl(css.typed_om.numeric, "multiplyTypes")) return std.testing.expect(false);
    const n = css.typed_om.numeric;
    const Type = css.math_values.Type;
    var highest = Type.one(.length);
    highest.powers[0] = std.math.maxInt(i32);
    const overflow = try n.multiplyTypes(highest, Type.one(.length));
    try std.testing.expectEqual(std.math.minInt(i32), overflow.powers[0]);
    var lowest = Type.one(.length);
    lowest.powers[0] = std.math.minInt(i32);
    const inverted = try n.invertType(lowest);
    try std.testing.expectEqual(std.math.minInt(i32), inverted.powers[0]);
    // A wrapping provisional length hint must not prevent a later angle hint.
    var percentage = highest;
    percentage.powers[6] = 1;
    var angle = highest;
    angle.powers[1] = 1;
    const result = try n.addTypes(percentage, angle);
    try std.testing.expectEqual(css.math_values.Base.angle, result.hint.?);
}

test "numeric conversion uses only compatible absolute units or exact relative units" {
    if (comptime !@hasDecl(css.typed_om, "numeric_ops")) return std.testing.expect(false);
    const convert = css.typed_om.numeric_ops.convert;
    try std.testing.expectEqual(@as(f64, 96), (try convert(.{ .value = 1, .unit = .in }, .px)).value);
    try std.testing.expectEqual(@as(f64, 1000), (try convert(.{ .value = 1, .unit = .s }, .ms)).value);
    try std.testing.expectEqual(@as(f64, 3), (try convert(.{ .value = 3, .unit = .em }, .em)).value);
    try std.testing.expectError(error.Invalid, convert(.{ .value = 1, .unit = .em }, .px));
    try std.testing.expectError(error.Invalid, convert(.{ .value = 1, .unit = .px }, .s));
}

fn graphOperations(a: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "numeric_ops")) return std.testing.expect(false);
    const ops = css.typed_om.numeric_ops;
    const Node = struct { view: ops.View, children: []const usize = &.{} };
    const Reader = struct {
        nodes: []const Node,
        pub fn view(self: @This(), id: usize) !ops.View {
            var result = self.nodes[id].view;
            result.count = self.nodes[id].children.len;
            return result;
        }
        pub fn child(self: @This(), id: usize, index: usize) !usize {
            return self.nodes[id].children[index];
        }
    };
    const nodes = [_]Node{
        .{ .view = .{ .kind = .unit, .number = .{ .value = 1, .unit = .in } } }, // 0
        .{ .view = .{ .kind = .unit, .number = .{ .value = 1, .unit = .px } } }, // 1
        .{ .view = .{ .kind = .unit, .number = .{ .value = 2, .unit = .em } } }, // 2
        .{ .view = .{ .kind = .sum }, .children = &.{ 0, 1 } }, // 3: 97px
        .{ .view = .{ .kind = .sum }, .children = &.{ 1, 2 } }, // 4
        .{ .view = .{ .kind = .product }, .children = &.{ 4, 4 } }, // 5
        .{ .view = .{ .kind = .invert }, .children = &.{3} }, // 6
        .{ .view = .{ .kind = .product }, .children = &.{ 3, 6 } }, // 7: 1
        .{ .view = .{ .kind = .negate }, .children = &.{3} }, // 8
        .{ .view = .{ .kind = .min }, .children = &.{ 0, 1 } }, // 9
        .{ .view = .{ .kind = .max }, .children = &.{ 0, 1 } }, // 10
        .{ .view = .{ .kind = .clamp }, .children = &.{ 1, 0, 3 } }, // 11
        .{ .view = .{ .kind = .sum }, .children = &.{ 1, 0 } }, // 12
        .{ .view = .{ .kind = .invert }, .children = &.{4} }, // 13: not a sum value
        .{ .view = .{ .kind = .sum }, .children = &.{ 1, 8 } }, // 14
    };
    const reader: Reader = .{ .nodes = &nodes };
    const cases = .{ .{ 3, 97.0, css.math_values.Unit.px }, .{ 7, 1.0, css.math_values.Unit.number }, .{ 8, -97.0, css.math_values.Unit.px }, .{ 9, 1.0, css.math_values.Unit.px }, .{ 10, 96.0, css.math_values.Unit.px }, .{ 11, 96.0, css.math_values.Unit.px } };
    inline for (cases) |case| {
        var sum = try ops.sumValue(a, case[0], reader);
        defer sum.deinit(a);
        try std.testing.expectEqual(@as(usize, 1), sum.items.len);
        const number = try sum.items[0].asNumeric();
        try std.testing.expectApproxEqAbs(@as(f64, case[1]), number.value, 1e-12);
        try std.testing.expectEqual(case[2], number.unit);
    }
    var square = try ops.sumValue(a, 5, reader);
    defer square.deinit(a);
    try std.testing.expectEqual(@as(usize, 4), square.items.len);
    for (square.items) |item| try std.testing.expectError(error.Invalid, item.asNumeric());
    // Q101: the allocator walk owns injected OOM; the domain error is Invalid.
    if (ops.sumValue(a, 13, reader)) |unexpected| {
        var owned = unexpected;
        owned.deinit(a);
        return error.TestExpectedError;
    } else |err| {
        if (err == error.OutOfMemory) return err;
        try std.testing.expect(err == error.Invalid);
    }
    try std.testing.expect(try ops.equals(a, 3, 3, reader));
    try std.testing.expect(!try ops.equals(a, 3, 12, reader));
    const text = try ops.serialize(a, 14, reader);
    defer a.free(text);
    try std.testing.expectEqualStrings("calc(1px - (1in + 1px))", text);
}

test "numeric graph algebra and serialization release all allocation failures" {
    try std.testing.checkAllAllocationFailures(allocator, graphOperations, .{});
}

test "deep math serialization and algebra use call-local stacks" {
    if (comptime !@hasDecl(css.typed_om, "numeric_ops")) return std.testing.expect(false);
    const ops = css.typed_om.numeric_ops;
    const Reader = struct {
        pub fn view(_: @This(), id: usize) !ops.View {
            return if (id == 5000) .{ .kind = .unit, .number = .{ .value = 7, .unit = .px } } else .{ .kind = .negate, .count = 1 };
        }
        pub fn child(_: @This(), id: usize, _: usize) !usize {
            return id + 1;
        }
    };
    var sum = try ops.sumValue(allocator, 0, Reader{});
    defer sum.deinit(allocator);
    try std.testing.expectEqual(@as(f64, 7), sum.items[0].value);
    const text = try ops.serialize(allocator, 0, Reader{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.startsWith(u8, text, "calc(-(-("));
    try std.testing.expect(try ops.equals(allocator, 0, 0, Reader{}));
}
