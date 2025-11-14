//! Tests migrated from src/dom/xpath/context.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");
const source = @import("../../src/dom/xpath/context.zig");

test "context - initialization" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    try std.testing.expectEqual(&node, ctx.context_node);
    try std.testing.expectEqual(@as(usize, 1), ctx.context_position);
    try std.testing.expectEqual(@as(usize, 1), ctx.context_size);
}
test "context - variable bindings" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    // Set variable
    const val = Value{ .number = 42.0 };
    try ctx.setVariable("myVar", val);

    // Get variable
    const retrieved = ctx.getVariable("myVar");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(f64, 42.0), retrieved.?.number);

    // Get non-existent variable
    const missing = ctx.getVariable("notFound");
    try std.testing.expect(missing == null);
}
test "context - namespace bindings" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    // Bind namespace
    try ctx.bindNamespace("xhtml", "http://www.w3.org/1999/xhtml");

    // Lookup namespace
    const uri = ctx.lookupNamespace("xhtml");
    try std.testing.expect(uri != null);
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xhtml", uri.?);

    // Lookup non-existent namespace
    const missing = ctx.lookupNamespace("notFound");
    try std.testing.expect(missing == null);
}
test "context - withNode" {
    const allocator = std.testing.allocator;
    var node1: Node = undefined;
    var node2: Node = undefined;

    var ctx = try Context.init(allocator, &node1);
    defer ctx.deinit();

    const new_ctx = ctx.withNode(&node2);
    try std.testing.expectEqual(&node2, new_ctx.context_node);
    try std.testing.expectEqual(ctx.context_position, new_ctx.context_position);
}
test "context - withPosition" {
    const allocator = std.testing.allocator;
    var node: Node = undefined;

    var ctx = try Context.init(allocator, &node);
    defer ctx.deinit();

    const new_ctx = ctx.withPosition(5, 10);
    try std.testing.expectEqual(ctx.context_node, new_ctx.context_node);
    try std.testing.expectEqual(@as(usize, 5), new_ctx.context_position);
    try std.testing.expectEqual(@as(usize, 10), new_ctx.context_size);
}
test "function library - registration and lookup" {
    const allocator = std.testing.allocator;

    var lib = try FunctionLibrary.init(allocator);
    defer lib.deinit();

    // Core functions should be registered
    const position_fn = lib.lookup("position");
    try std.testing.expect(position_fn != null);

    const not_fn = lib.lookup("not");
    try std.testing.expect(not_fn != null);

    // Non-existent function
    const missing = lib.lookup("notAFunction");
    try std.testing.expect(missing == null);
}