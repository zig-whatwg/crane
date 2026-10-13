const std = @import("std");
const up = @import("urlpattern");

fn parseWithFailures(allocator: std.mem.Allocator) !void {
    var parsed = try up.parsePatternString(allocator, "/{pre:name(a|b)suffix}+/next", up.parser.pathname_options, up.parser.identityEncoding);
    defer parsed.deinit();
}

test "URLPattern parser releases partial parts on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseWithFailures, .{});
}
