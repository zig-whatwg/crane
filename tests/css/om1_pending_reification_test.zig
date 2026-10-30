//! Typed OM §§5.3–5.4 and Q31/Q34 (2026-10-27): existing Pending nodes
//! reify without another property parser or any substitution workaround.
const std = @import("std");
const css = @import("css");

fn roundtrip(allocator: std.mem.Allocator, source: []const u8, expected: []const u8, count: usize) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "pending_reification")) return std.testing.expect(false);
    const pending = (try css.pending_values.Pending.create(.{ .allocator = allocator }, .{ .longhand = .width }, source)) orelse return error.TestUnexpectedResult;
    defer pending.unref();
    const graph = try css.typed_om.pending_reification.fromNodes(allocator, pending.nodes);
    defer graph.deinit();
    try std.testing.expectEqual(count, try graph.length(0));
    const text = try css.typed_om.unparsed.serialize(allocator, 0, graph);
    defer allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn probeCases(allocator: std.mem.Allocator) anyerror!void {
    try roundtrip(allocator, "env(safe-area-inset-top)", "env(safe-area-inset-top)", 1);
    try roundtrip(allocator, "attr(data-w px, 1px)", "attr(data-w px, 1px)", 1);
    try roundtrip(allocator, "if(style(--x: 1): 2px; else: 3px)", "if(style(--x: 1): 2px; else: 3px)", 1);
    try roundtrip(allocator, "calc(1px + var(--a\\ b, var(--c, 2px)))", "calc(1px + var(--a b, var(--c, 2px)))", 3);
    try roundtrip(allocator, "var(var(--a), 1px)", "var(var(--a), 1px)", 3);
    try roundtrip(allocator, "var(attr(data-n type(<custom-ident>)), 2px)", "var(attr(data-n type(<custom-ident>)), 2px)", 1);
    try roundtrip(allocator, "var(var(--a), var(--b, 3px))", "var(var(--a), var(--b, 3px))", 5);
    try roundtrip(allocator, "env(foo, var(--a))", "env(foo, var(--a))", 3);
}

test "unparsed reification covers the real substitution grammar with allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, probeCases, .{});
}

test "variable names decode while fallback whitespace and empty fallback presence survive" {
    if (comptime !@hasDecl(css.typed_om, "pending_reification")) return std.testing.expect(false);
    const allocator = std.testing.allocator;
    const pending = (try css.pending_values.Pending.create(.{ .allocator = allocator }, .{ .longhand = .width }, "var(--a\\ b, var(--c,))")) orelse return error.TestUnexpectedResult;
    defer pending.unref();
    const graph = try css.typed_om.pending_reification.fromNodes(allocator, pending.nodes);
    defer graph.deinit();
    const outer = (try graph.segment(0, 0)).variable;
    try std.testing.expectEqualStrings("--a b", outer.name);
    const fallback = outer.fallback orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(" ", (try graph.segment(fallback, 0)).string);
    const inner = (try graph.segment(fallback, 1)).variable;
    try std.testing.expectEqualStrings("--c", inner.name);
    try std.testing.expectEqual(@as(usize, 0), try graph.length(inner.fallback orelse return error.TestUnexpectedResult));
}
