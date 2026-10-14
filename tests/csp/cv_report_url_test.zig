const std = @import("std");
const csp = @import("csp");

test "CSP reports preserve WebSocket URLs but remove their credentials and fragment" {
    const allocator = std.testing.allocator;
    for ([_][2][]const u8{
        .{ "ws://example.test/a.js", "ws://example.test/a.js" },
        .{ "wss://user:secret@example.test:8443/a.js?q=1#hidden", "wss://example.test:8443/a.js?q=1" },
        .{ "wss://example.test/a.js?q=user@host#fragment", "wss://example.test/a.js?q=user@host" },
    }) |case| {
        const source = try csp.violation_events.sourceFileForReports(allocator, case[0]);
        defer allocator.free(source);
        try std.testing.expectEqualStrings(case[1], source);
        const blocked = try csp.violation_events.blockedUri(allocator, .{ .url = case[0] });
        defer allocator.free(blocked);
        try std.testing.expectEqualStrings(case[1], blocked);
    }
}

test "CSP source URL filtering preserves query under Firefox and WebKit behavior" {
    const allocator = std.testing.allocator;
    const source = try csp.violation_events.sourceFileForReports(allocator, "https://user:secret@example.test/a.js?q=1#hidden");
    defer allocator.free(source);
    try std.testing.expectEqualStrings("https://example.test/a.js?q=1", source);
}
