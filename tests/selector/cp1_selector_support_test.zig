//! Conditional Rules 4 section 2.1 distinguishes forgiving syntax from support.
const std = @import("std");
const selector = @import("selector");

fn cases(a: std.mem.Allocator) !void {
    for ([_][]const u8{ ":has(:is(:has(*)))", ":has(:where(:has(*)))", ":has(:is(.a, 123))", ":is(.a, :unknown)", "a, b", "::-webkit-unknown-example" }) |input| {
        try std.testing.expect(!try selector.isSupported(a, input, .{}));
    }
    for ([_][]const u8{ "a", ":has(:is(.a, .b))", ":where(.a):not(.b)", ":nth-child(2n of :is(.a, .b))" }) |input| {
        try std.testing.expect(try selector.isSupported(a, input, .{}));
    }
}

test "support rejects invalid branches even when ordinary parsing forgives them" {
    try cases(std.testing.allocator);
    var parsed = try selector.parse(std.testing.allocator, ":has(:is(.a, 123))");
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.selectors.len);
}

test "support checking propagates and unwinds allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cases, .{});
}
