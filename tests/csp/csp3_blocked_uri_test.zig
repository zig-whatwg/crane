const std = @import("std");
const events = @import("csp").violation_events;

test "blocked URI redacts cross-origin frame and object paths only" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { directive: []const u8, origin: []const u8, resource: []const u8, expected: []const u8 }{
        .{ .directive = "frame-src", .origin = "https://a.test", .resource = "https://b.test/private?key=1#frag", .expected = "https://b.test" },
        .{ .directive = "object-src", .origin = "https://a.test", .resource = "https://user:secret@b.test:8443/private?key=1#frag", .expected = "https://b.test:8443" },
        .{ .directive = "frame-src", .origin = "https://a.test", .resource = "https://a.test/private?key=1#frag", .expected = "https://a.test/private?key=1" },
        .{ .directive = "frame-src", .origin = "https://a.test:443", .resource = "https://a.test/private", .expected = "https://a.test/private" },
        .{ .directive = "frame-src", .origin = "http://a.test", .resource = "https://a.test/private", .expected = "https://a.test" },
        .{ .directive = "frame-src", .origin = "https://a.test:8443", .resource = "https://a.test/private", .expected = "https://a.test" },
        .{ .directive = "frame-src", .origin = "null", .resource = "https://a.test/private", .expected = "https://a.test" },
        .{ .directive = "frame-src", .origin = "https://[::1]", .resource = "https://[::2]:8443/private", .expected = "https://[::2]:8443" },
        .{ .directive = "img-src", .origin = "https://a.test", .resource = "https://b.test/private?key=1#frag", .expected = "https://b.test/private?key=1" },
        .{ .directive = "frame-src", .origin = "https://a.test", .resource = "data:text/html,private", .expected = "data" },
    };
    for (cases) |case| {
        const value = try events.blockedUriForPolicy(allocator, .{ .url = case.resource }, case.directive, case.origin);
        defer allocator.free(value);
        try std.testing.expectEqualStrings(case.expected, value);
    }
    const value = try events.blockedUriForPolicy(allocator, .@"inline", "frame-src", "null");
    defer allocator.free(value);
    try std.testing.expectEqualStrings("inline", value);
}
