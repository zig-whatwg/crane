//! Both return forms of Fetch HTTP quoted-string collection own their result.
const std = @import("std");
const fetch = @import("fetch");

fn quoteAllocationTrial(allocator: std.mem.Allocator) !void {
    for ([_]bool{ false, true }) |extract_value| {
        var position: usize = 0;
        const result = try fetch.internal.collectHttpQuotedString(allocator, "\"a\\\"b\"tail", &position, extract_value);
        defer allocator.free(result);
        try std.testing.expectEqualStrings(if (extract_value) "a\"b" else "\"a\\\"b\"", result);
        try std.testing.expectEqual(@as(usize, 6), position);
    }
}

test "raw HTTP quoted string releases allocations on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, quoteAllocationTrial, .{});
}
