//! Counted declaration values remain owned on every partial shorthand failure.
const std = @import("std");
const css = @import("css");

test "declaration parsing releases retained values when the entries allocation fails" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseBlock, .{});
}

fn parseBlock(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-color:red green blue yellow;font-family:example, serif");
    defer block.deinit();
}

test "CSSOM shorthand assignment releases values after a partially consumed list" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, setBlock, .{});
}

fn setBlock(allocator: std.mem.Allocator) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "border-color", "red green blue yellow", "");
}
