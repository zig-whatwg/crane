const std = @import("std");
const parser = @import("url").parser.basic_url_parser;

fn construct(allocator: std.mem.Allocator, input: []const u8) !void {
    var record = try parser.parse(allocator, input, null);
    defer record.deinit();
}

test "URL record construction releases completed fields after later allocation failures" {
    for ([_][]const u8{
        "https://user:password@child.test:8443/one/two?query=value#fragment",
        "data:text/plain,opaque-path?query#fragment",
        "file:///one/two",
    }) |input| {
        try std.testing.checkAllAllocationFailures(std.testing.allocator, construct, .{input});
    }
}
