//! Preserve the shared unavailable-metrics rule across this lane's value tags.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn cursorControl(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:url(pointer.cur) 1 2, pointer");
    defer block.deinit();
    const value = (block.get(.cursor) orelse return error.ExpectedCursor).value.value;
    try testing.expect(value == .cursor);
    try testing.expect(!value.needsUnavailableMetrics(false));
    try testing.expect(!value.needsUnavailableMetrics(true));
}

test "cursor URL candidates and numeric hotspots require no font metrics" {
    try testing.checkAllAllocationFailures(testing.allocator, cursorControl, .{});
}

fn indentForwarding(allocator: std.mem.Allocator, metric: bool) !void {
    const input = if (metric) "text-indent:calc(1cap + 1px) hanging" else "text-indent:2em hanging";
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    const value = (block.get(.text_indent) orelse return error.ExpectedIndent).value.value;
    try testing.expect(value == .indent);
    try testing.expectEqual(metric, value.needsUnavailableMetrics(false));
    // The aggregate forwards the caller's geometry flag unchanged.
    try testing.expect(!value.needsUnavailableMetrics(true));
}

test "flagged text-indent forwards unavailable-metric checks to its owned scalar" {
    try testing.checkAllAllocationFailures(testing.allocator, indentForwarding, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, indentForwarding, .{true});
}

fn nextCandidate(allocator: std.mem.Allocator) !void {
    var lower = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-indent:3px hanging");
    defer lower.deinit();
    var higher = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-indent:calc(1cap + 1px) hanging");
    defer higher.deinit();
    try testing.expect(higher.get(.text_indent) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &lower, .source = .{ .origin = .user } },
        .{ .block = &higher, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.text_indent, &out, allocator);
    try testing.expectEqualStrings("3px hanging", out.items);
}

test "an unavailable nested text-indent metric selects the next retained candidate" {
    try testing.checkAllAllocationFailures(testing.allocator, nextCandidate, .{});
}
