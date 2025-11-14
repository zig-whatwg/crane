//! Tests migrated from src/dom/xpath/ast.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");
const source = @import("../../src/dom/xpath/ast.zig");

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
test "ast - function call creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: position()
    const expr = try createFunctionCall(allocator, "position", &[_]*Expr{});

    try std.testing.expectEqual(Expr.primary_expr, std.meta.activeTag(expr.*));
    try std.testing.expectEqual(PrimaryExpr.function_call, std.meta.activeTag(expr.primary_expr));
    try std.testing.expectEqualStrings("position", expr.primary_expr.function_call.name);
    try std.testing.expectEqual(@as(usize, 0), expr.primary_expr.function_call.arguments.len);
}
test "ast - location path creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create: child::para
    const steps = try allocator.alloc(Step, 1);
    steps[0] = try createStep(
        allocator,
        .child,
        .{ .name_test = .{ .qname = .{ .prefix = null, .local = "para" } } },
        &[_]*Expr{},
    );

    const path = LocationPath{ .relative = .{ .steps = steps } };
    const expr = try createLocationPath(allocator, path);

    try std.testing.expectEqual(Expr.location_path, std.meta.activeTag(expr.*));
    try std.testing.expect(!expr.location_path.isAbsolute());
}
test "ast - axis properties" {
    // Test forward/reverse axes
    try std.testing.expect(Axis.child.isForward());
    try std.testing.expect(Axis.parent.isReverse());

    // Test principal node types
    try std.testing.expectEqual(Axis.PrincipalNodeType.element, Axis.child.principalNodeType());
    try std.testing.expectEqual(Axis.PrincipalNodeType.attribute, Axis.attribute.principalNodeType());
    try std.testing.expectEqual(Axis.PrincipalNodeType.namespace, Axis.namespace.principalNodeType());
}
test "ast - node test types" {
    // Wildcard
    const wildcard = NodeTest{ .name_test = .wildcard };
    try std.testing.expectEqual(NodeTest.name_test, std.meta.activeTag(wildcard));

    // QName
    const qname = NodeTest{ .name_test = .{ .qname = .{ .prefix = null, .local = "para" } } };
    try std.testing.expectEqual(NodeTest.name_test, std.meta.activeTag(qname));

    // Node type
    const node_type = NodeTest{ .node_type = .text };
    try std.testing.expectEqual(NodeTest.node_type, std.meta.activeTag(node_type));
}