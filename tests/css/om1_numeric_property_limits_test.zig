//! CSS Values4 §10.8 and liaison Q85/Q89,2026-10-27: shared ceilings
//! count parser calls for text and operation occurrences for native input.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

const Chain = struct {
    depth: usize,
    pub fn view(self: @This(), id: usize) !css.typed_om.numeric_ops.View {
        if (id < self.depth) return .{ .kind = if (id % 2 == 0) .min else .max, .count = 2 };
        if (id == self.depth) return .{ .kind = .unit, .number = .{ .value = 1, .unit = .em } };
        if (id == self.depth + 1) return .{ .kind = .unit, .number = .{ .value = 1, .unit = .vw } };
        return error.Invalid;
    }
    pub fn child(self: @This(), id: usize, index: usize) !usize {
        return if (index == 0) id + 1 else self.depth + 1;
    }
};

fn chain(allocator: std.mem.Allocator, depth: usize, accept: bool) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_numeric")) return std.testing.expect(false);
    if (comptime !@hasDecl(css.typed_om.native_numeric, "snapshotForProperty")) return std.testing.expect(false);
    const result = css.typed_om.native_numeric.snapshotForProperty(allocator, 0, Chain{ .depth = depth });
    if (!accept) {
        if (result) |unexpected| {
            unexpected.deinit();
            return error.TestUnexpectedResult;
        } else |err| {
            if (err == error.OutOfMemory) return err;
            try std.testing.expectEqual(error.Invalid, err);
            return;
        }
    }
    const tree = try result;
    defer tree.deinit();
    var node = tree.root;
    var count: usize = 0;
    while (node.tag != .numeric) : (count += 1) node = node.children[0];
    try std.testing.expectEqual(depth, count);
    const assigned = (try css.math_values.fromTypedNumeric(allocator, tree, false, .{ .kind = .length_percentage })) orelse return error.TestExpectedValue;
    defer assigned.unref();
    // Reaching the existing property simplifier/compute is safe at the bound.
    const computed = try assigned.compute(allocator, .{});
    defer computed.unref();
}

test "Q85 native property accepts the required32 unresolved levels without leaks" {
    try std.testing.checkAllAllocationFailures(a, chain, .{ 32, true });
}
test "Q85 native property accepts128 unresolved levels at the property limit" {
    try std.testing.checkAllAllocationFailures(a, chain, .{ 128, true });
}
test "Q85 native property rejects129 unresolved levels with allocation failure cleanup" {
    try std.testing.checkAllAllocationFailures(a, chain, .{ 129, false });
}
test "Q85 native property rejects5000 unresolved levels before expansion" {
    try std.testing.checkAllAllocationFailures(a, chain, .{ 5000, false });
}

fn operations(count: usize, accept: bool) !void {
    if (comptime !@hasDecl(css.typed_om, "native_numeric")) return std.testing.expect(false);
    if (comptime !@hasDecl(css.typed_om.native_numeric, "snapshotForProperty")) return std.testing.expect(false);
    const Reader = struct {
        count: usize,
        pub fn view(self: @This(), id: usize) !css.typed_om.numeric_ops.View {
            return switch (id) {
                0 => .{ .kind = .sum, .count = self.count - 1 },
                1 => .{ .kind = .min, .count = 2 },
                2 => .{ .kind = .unit, .number = .{ .value = 1, .unit = .em } },
                3 => .{ .kind = .unit, .number = .{ .value = 1, .unit = .vw } },
                else => error.Invalid,
            };
        }
        pub fn child(_: @This(), id: usize, index: usize) !usize {
            return if (id == 0) 1 else index + 2;
        }
    };
    const result = css.typed_om.native_numeric.snapshotForProperty(a, 0, Reader{ .count = count });
    if (accept) {
        const tree = try result;
        defer tree.deinit();
        try std.testing.expectEqual(count - 1, tree.root.children.len);
    } else if (result) |unexpected| {
        unexpected.deinit();
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expectEqual(error.Invalid, err);
}

test "Q85 native property supports4096 expanded operations and rejects4097" {
    try operations(4096, true);
    try operations(4097, false);
}

fn textDepth(depth: usize, accept: bool) !void {
    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(a);
    for (0..depth) |_| try source.appendSlice(a, "min(1em, ");
    try source.appendSlice(a, "1vw");
    for (0..depth) |_| try source.append(a, ')');
    const result = try css.math_values.parse(a, source.items, .{ .kind = .length_percentage });
    if (result) |parsed| {
        defer parsed.expression.unref();
        try std.testing.expect(accept);
    } else try std.testing.expect(!accept);
}
fn textMinChildren(count: usize, accept: bool) !void {
    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(a);
    try source.appendSlice(a, "calc(");
    for (0..count) |i| {
        if (i > 0) try source.appendSlice(a, " + ");
        try source.appendSlice(a, "min(1em, 1vw)");
    }
    try source.append(a, ')');
    const result = try css.math_values.parse(a, source.items, .{ .kind = .length_percentage });
    if (result) |parsed| {
        defer parsed.expression.unref();
        try std.testing.expect(accept);
    } else try std.testing.expect(!accept);
}

test "Q89 text parser preserves its measured call-budget boundaries" {
    // D109 receipt,2026-10-27: function AND primary consume parser calls.
    // Original Q85 expectation/input and failed log are preserved separately.
    try textDepth(32, true);
    try textDepth(64, true);
    try textDepth(65, false);
    try textDepth(128, false);
    try textMinChildren(1023, true);
    try textMinChildren(1024, false);
}
test "Q85 parser limit constants retain their measured values" {
    if (comptime !@hasDecl(css.math_values, "calculation_max_depth")) return std.testing.expect(false);
    try std.testing.expectEqual(@as(usize, 128), css.math_values.calculation_max_depth);
    try std.testing.expectEqual(@as(usize, 4096), css.math_values.calculation_max_nodes);
}

fn coherent(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_numeric")) return std.testing.expect(false);
    if (comptime !@hasDecl(css.typed_om.native_numeric, "snapshotForProperty")) return std.testing.expect(false);
    const Reader = struct {
        pub fn view(_: @This(), id: usize) !css.typed_om.numeric_ops.View {
            if (id < 32) return switch (id % 3) {
                0 => .{ .kind = .min, .count = 2 },
                1 => .{ .kind = .sum, .count = 2 },
                2 => .{ .kind = .negate, .count = 1 },
                else => unreachable,
            };
            return if (id == 32)
                .{ .kind = .unit, .number = .{ .value = 1, .unit = .em } }
            else if (id == 33)
                .{ .kind = .unit, .number = .{ .value = 1, .unit = .vw } }
            else
                error.Invalid;
        }
        pub fn child(_: @This(), id: usize, index: usize) !usize {
            return if (index == 0) id + 1 else 33;
        }
    };
    const tree = try css.typed_om.native_numeric.snapshotForProperty(allocator, 0, Reader{});
    defer tree.deinit();
    const assigned = try css.math_values.fromTypedNumeric(allocator, tree, false, .{ .kind = .length_percentage }) orelse return error.TestExpectedValue;
    defer assigned.unref();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try assigned.serialize(&text, allocator);
    const reparsed = try css.math_values.parse(allocator, text.items, .{ .kind = .length_percentage }) orelse return error.TestExpectedValue;
    defer reparsed.expression.unref();
    try std.testing.expect(text.items.len != 0);
}

test "Q89 guaranteed32 mixed min sum negate property levels roundtrip through CSS text" {
    try std.testing.checkAllAllocationFailures(a, coherent, .{});
}
