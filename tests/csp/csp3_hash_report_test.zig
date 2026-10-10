const std = @import("std");
const csp = @import("csp");

test "hash report URL strips credentials and fragment while preserving the path" {
    const value = try csp.violation_events.stripUrlForReports(std.testing.allocator, "https://user:password@other.test:8443/private?q=1#secret");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings("https://other.test:8443/private?q=1", value);
}

test "hash reporting chooses the strongest keyword independent of order" {
    const cases = [_]struct { source: []const u8, algorithm: ?csp.HashAlgorithm }{
        .{ .source = "'self'", .algorithm = null },
        .{ .source = "'report-sha256'", .algorithm = .sha256 },
        .{ .source = "'report-sha384' 'report-sha256'", .algorithm = .sha384 },
        .{ .source = "'report-sha512' 'report-sha256' 'report-sha384'", .algorithm = .sha512 },
        .{ .source = "'REPORT-SHA384'", .algorithm = .sha384 },
        .{ .source = "report-sha512 'report-sha1' 'report-sha256-extra'", .algorithm = null },
    };
    for (cases) |case| {
        const text = try std.fmt.allocPrint(std.testing.allocator, "script-src {s}", .{case.source});
        defer std.testing.allocator.free(text);
        var policy = try csp.parsing.parseSerializedCSP(std.testing.allocator, text, .header, .enforce);
        defer policy.deinit();
        try std.testing.expectEqual(case.algorithm, csp.hash.reportingAlgorithm(&policy.getDirective("script-src").?.value));
    }
}

test "hash report uses response bytes and standard base64, with no opaque body disclosure" {
    const allocator = std.testing.allocator;
    // Upstream report-hash's response and independent Server-Timing vectors.
    const body = "// Ceci n'est pas un commentaire\n";
    const cases = [_][2][]const u8{
        .{ "'report-sha256'", "sha256-1XF/E08XndkoxwN6eIa5J89hYn3OVZ/UyB8BrU5jgzk=" },
        .{ "'report-sha512' 'report-sha256'", "sha512-hG4x56V5IhUUepZdYU/lX7UOQJ2M7f6ud2EI7os4JV3OwXSZ002P3zkb9tXQkjpOO8UbtjuEufvdcU67Qt2tlw==" },
    };
    for (cases) |case| {
        const text = try std.fmt.allocPrint(allocator, "script-src {s}", .{case[0]});
        defer allocator.free(text);
        var policy = try csp.parsing.parseSerializedCSP(allocator, text, .header, .enforce);
        defer policy.deinit();
        const source_list = &policy.getDirective("script-src").?.value;
        const value = (try csp.hash.hashForReport(allocator, source_list, body)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings(case[1], value);
        const hidden = (try csp.hash.hashForReport(allocator, source_list, null)).?;
        defer allocator.free(hidden);
        try std.testing.expectEqualStrings("", hidden);
    }
}

test "hash report distinguishes no report from empty and opaque response bodies" {
    const allocator = std.testing.allocator;
    var none = try csp.parsing.parseSerializedCSP(allocator, "script-src 'self'", .header, .enforce);
    defer none.deinit();
    try std.testing.expect(try csp.hash.hashForReport(allocator, &none.getDirective("script-src").?.value, "") == null);
    var sha = try csp.parsing.parseSerializedCSP(allocator, "script-src 'report-sha256'", .header, .report);
    defer sha.deinit();
    const empty = (try csp.hash.hashForReport(allocator, &sha.getDirective("script-src").?.value, "")).?;
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=", empty);
}
