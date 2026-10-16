//! Inherited policies retain the URL against which report-uri was delivered.
const std = @import("std");
const csp = @import("csp");

test "a policy without delivery provenance defaults to no delivery URL" {
    if (comptime !@hasField(csp.Policy, "delivery_url")) return error.TestUnexpectedResult;
    var policy = csp.Policy.init(std.testing.allocator, .enforce, .header);
    defer policy.deinit();
    try std.testing.expect(policy.delivery_url == null);
}

test "copyList deep-copies each policy delivery URL for inherited reports" {
    if (comptime !@hasField(csp.Policy, "delivery_url")) return error.TestUnexpectedResult;
    const a = std.testing.allocator;
    var original = csp.CSPList.init(a);
    defer original.deinit();
    for ([_][]const u8{ "https://parent.test/a/page", "https://parent.test/b/page" }) |url| {
        var policy = try csp.parseSerializedCSP(a, "script-src 'none'; report-uri ../reports", .header, .enforce);
        errdefer policy.deinit();
        policy.delivery_url = try a.dupe(u8, url);
        try original.append(policy);
    }
    var inherited = try csp.parsing.copyList(a, &original);
    defer inherited.deinit();
    try std.testing.expectEqual(@as(usize, 2), inherited.policies.items.len);
    for (original.policies.items, inherited.policies.items) |before, after| {
        try std.testing.expectEqualStrings(before.delivery_url.?, after.delivery_url.?);
        try std.testing.expect(before.delivery_url.?.ptr != after.delivery_url.?.ptr);
    }
    original.policies.items[0].delivery_url.?[0] = 'X';
    try std.testing.expectEqualStrings("https://parent.test/a/page", inherited.policies.items[0].delivery_url.?);

    const Copy = struct {
        fn run(allocator: std.mem.Allocator, source: *const csp.CSPList) !void {
            var result = try csp.parsing.copyList(allocator, source);
            defer result.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(a, Copy.run, .{&original});
}
