//! Each generator allocation failure must release both names and expression.
const std = @import("std");
const up = @import("urlpattern");
const A = std.testing.allocator;

fn allocationFailures(allocator: std.mem.Allocator) !void {
    // Keep parsing outside the allocator under test: this pins the generator's
    // ownership transfer of names and its two independently allocated results.
    var parts = try up.parsePatternString(A, "/:name+/{pre:other(a|b)suf}?", up.parser.pathname_options, up.identityEncoding);
    defer parts.deinit();
    var result = try up.generateRegexAndNameList(allocator, parts.parts, up.parser.pathname_options);
    defer result.deinit();
}

test "URLPattern regexp generator releases names and output on allocation failure" {
    try std.testing.checkAllAllocationFailures(A, allocationFailures, .{});
}
