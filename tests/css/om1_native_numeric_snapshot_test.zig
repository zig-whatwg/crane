//! Typed OM native input snapshots the existing numeric IR without text.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn check(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_numeric")) return std.testing.expect(false);
    const Reader = struct {
        length: f64 = 2,
        pub fn view(self: @This(), id: usize) !css.typed_om.numeric_ops.View {
            return switch (id) {
                0 => .{ .kind = .sum, .count = 2 },
                1 => .{ .kind = .unit, .number = .{ .value = self.length, .unit = .px } },
                2 => .{ .kind = .product, .count = 2 },
                3 => .{ .kind = .unit, .number = .{ .value = 3, .unit = .number } },
                4 => .{ .kind = .unit, .number = .{ .value = 4, .unit = .cm } },
                else => error.Invalid,
            };
        }
        pub fn child(_: @This(), id: usize, index: usize) !usize {
            return switch (id) {
                0 => if (index == 0) 1 else 2,
                2 => if (index == 0) 3 else 4,
                else => error.Invalid,
            };
        }
    };
    var reader: Reader = .{};
    const tree = try css.typed_om.native_numeric.snapshot(allocator, 0, reader);
    defer tree.deinit();
    reader.length = 99;
    try std.testing.expectEqual(css.math_values.Node.Tag.sum, tree.root.tag);
    try std.testing.expectEqual(@as(f64, 2), tree.root.children[0].numeric.value);
    try std.testing.expectEqual(css.math_values.Unit.px, tree.root.children[0].numeric.unit);
    try std.testing.expectEqual(css.math_values.Node.Tag.product, tree.root.children[1].tag);
    try std.testing.expectEqual(css.math_values.Unit.cm, tree.root.children[1].children[1].numeric.unit);
    try std.testing.expect(tree.root.typ.eql(css.math_values.Type.one(.length)));
    // The owning grammar, not this snapshotter, simplifies and canonicalizes.
    const assigned = (try css.math_values.fromTypedNumeric(allocator, tree, false, .{ .kind = .length })) orelse return error.TestExpectedValue;
    defer assigned.unref();
    try std.testing.expectEqual(css.math_values.Node.Tag.numeric, assigned.root.tag);
    try std.testing.expectApproxEqAbs(@as(f64, 2) + @as(f64, 12) * 96 / 2.54, assigned.root.numeric.value, 0.000001);
}

test "numeric input snapshots native unit and operation fields independently of later mutation" {
    try std.testing.checkAllAllocationFailures(a, check, .{});
}

test "numeric input snapshot walks deep existing trees without native recursion" {
    if (comptime !@hasDecl(css.typed_om, "native_numeric")) return std.testing.expect(false);
    const Reader = struct {
        pub fn view(_: @This(), id: usize) !css.typed_om.numeric_ops.View {
            return if (id == 5000) .{ .kind = .unit, .number = .{ .value = 2, .unit = .px } } else .{ .kind = .sum, .count = 1 };
        }
        pub fn child(_: @This(), id: usize, _: usize) !usize {
            return id + 1;
        }
    };
    const tree = try css.typed_om.native_numeric.snapshot(a, 0, Reader{});
    defer tree.deinit();
    var node = tree.root;
    var count: usize = 0;
    while (node.tag != .numeric) : (count += 1) node = node.children[0];
    try std.testing.expectEqual(@as(usize, 5000), count);
    try std.testing.expectEqual(@as(f64, 2), node.numeric.value);
}
