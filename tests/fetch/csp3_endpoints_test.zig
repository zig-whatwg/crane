const std = @import("std");
const PolicyContainer = @import("fetch").internal.PolicyContainer;

test "Reporting-Endpoints resolves strings, replaces duplicate names, and ignores other valid SF types" {
    var container = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://example.test/dir/page",
        .reporting_endpoints = "group=\"/old\", integer=-999999999999999, decimal=123456789012.123, token=foo/bar:xyz, bool=?0, implicit;p=\"x\", bytes=:aGVsbG8=:, date=@-123, display=%\"caf%c3%a9\", list=(\"ignored\";a=1 ?1);x, group=\"../reports\";ignored=token, second=\"https://other.test/endpoint\"",
    });
    defer container.deinit();
    const endpoints = container.endpoints.?;
    try std.testing.expectEqual(@as(usize, 2), endpoints.items.items.len);
    try std.testing.expectEqualStrings("group", endpoints.items.items[0].name);
    try std.testing.expectEqualStrings("https://example.test/reports", endpoints.items.items[0].url);
    try std.testing.expectEqual(@as(u64, 0), endpoints.items.items[0].failures);
    try std.testing.expectEqualStrings("https://other.test/endpoint", endpoints.items.items[1].url);
    var clone = try container.clone(std.testing.allocator);
    defer clone.deinit();
    try std.testing.expect(clone.endpoints == null);
}

test "Reporting-Endpoints rejects an entire malformed dictionary including ignored members" {
    const bad = [_][]const u8{
        "Bad=1",    "a=\"unterminated", "a=\"bad\\n\"",   "a=?2",          "a=1000000000000000", "a=1234567890123.0",
        "a=1.1234", "a=1.",             "a=@1.5",         "a=%\"%C3%a9\"", "a=%\"%ff\"",         "a=%\"%c3\"",
        "a=:a:",    "a=:**:",           "a=:a===:",       "a=(?1\t?0)",    "a=((1))",            "a=1,",
        "a=1,,b=2", "a=1;=x",           "a =1",           "a= 1",          "a=\"\x7f\"",         "a=\"\xc3\xa9\"",
        "a=+1",     "a=1;b=",           "a=:aGVs\nbG8=:",
    };
    for (bad) |suffix| {
        const header = try std.fmt.allocPrint(std.testing.allocator, "ok=\"/reports\", {s}", .{suffix});
        defer std.testing.allocator.free(header);
        var container = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
            .url = "https://example.test/",
            .reporting_endpoints = header,
        });
        defer container.deinit();
        try std.testing.expect(container.endpoints == null);
    }
}

test "Reporting-Endpoints requires trustworthy response and endpoint origins" {
    var insecure = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "http://example.test/",
        .reporting_endpoints = "a=\"https://example.test/report\"",
    });
    defer insecure.deinit();
    try std.testing.expect(insecure.endpoints == null);
    var container = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "http://localhost/page",
        .reporting_endpoints = "a=\"/report\", b=\"http://insecure.test/report\", c=\"http://127.0.0.1/report\", d=\"data:,bad\", e=\"https://[bad\"",
    });
    defer container.deinit();
    try std.testing.expectEqual(@as(usize, 2), container.endpoints.?.items.items.len);
    try std.testing.expectEqualStrings("http://localhost/report", container.endpoints.?.items.items[0].url);
    try std.testing.expectEqualStrings("http://127.0.0.1/report", container.endpoints.?.items.items[1].url);
}

test "Reporting-Endpoints validates parameters and bytes without confusing display strings with strings" {
    var container = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://example.test/page",
        .reporting_endpoints = "a=\"/report\";x=?0;x=?1; y=(bad)",
    });
    defer container.deinit();
    try std.testing.expect(container.endpoints == null);
    var valid = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://example.test/page",
        .reporting_endpoints = "a=\"/report\";x=?0;x=?1; y=%\"%c3%a9\", b=:aGVsbG8:, c=:Zh==:, d=%\"https://other.test/\", e=:Zg=:",
    });
    defer valid.deinit();
    try std.testing.expect(valid.endpoints != null);
    try std.testing.expectEqual(@as(usize, 1), valid.endpoints.?.items.items.len);
}
