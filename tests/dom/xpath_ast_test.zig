//! Tests migrated from src/dom/xpath/ast.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");

test "ast - binary expression creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: 5 + 3
    const left = try createPrimaryExpr(allocator, .{ .number = 5.0 });
    const right = try createPrimaryExpr(allocator, .{ .number = 3.0 });
    const expr = try createBinaryExpr(allocator, .plus, left, right);

    try std.testing.expectEqual(Expr.additive_expr, std.meta.activeTag(expr.*));
}