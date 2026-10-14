const std = @import("std");
const csp = @import("csp");

test "CSP directive values reject non-whitespace control bytes and DEL" {
    const allocator = std.testing.allocator;
    for (0..128) |value| {
        const byte: u8 = @intCast(value);
        if (byte >= 0x20 and byte != 0x7f) continue;
        if (std.mem.indexOfScalar(u8, "\t\n\x0c\r ", byte) != null) continue;
        const serialized = try std.fmt.allocPrint(allocator, "img-src 'none'{c}; script-src 'none'", .{byte});
        defer allocator.free(serialized);
        var policy = try csp.parsing.parseSerializedCSP(allocator, serialized, .header, .enforce);
        defer policy.deinit();
        try std.testing.expect(policy.getDirective("img-src") == null);
        try std.testing.expect(policy.getDirective("script-src").?.value.isNone());
    }
}

test "CSP vertical tab is neither trimming whitespace nor a token separator" {
    for ([_][]const u8{
        "\x0bimg-src 'none'",
        "img-src\x0b'none'",
        "img-src 'none'\x0b",
        "img-src https://one.test\x0bhttps://two.test",
    }) |serialized| {
        var policy = try csp.parsing.parseSerializedCSP(std.testing.allocator, serialized, .meta, .enforce);
        defer policy.deinit();
        try std.testing.expect(policy.getDirective("img-src") == null);
    }
}

test "CSP accepts all five Infra ASCII whitespace characters and keeps first valid directive" {
    const allocator = std.testing.allocator;
    for ("\t\n\x0c\r ") |byte| {
        const serialized = try std.fmt.allocPrint(allocator, "{c}ImG-SrC{c}'none'{c}; img-src *; script-src 'self'", .{ byte, byte, byte });
        defer allocator.free(serialized);
        var policy = try csp.parsing.parseSerializedCSP(allocator, serialized, .meta, .report);
        defer policy.deinit();
        try std.testing.expect(policy.getDirective("img-src").?.value.isNone());
        try std.testing.expect(policy.getDirective("script-src").?.value.contains(.keyword_self));
        try std.testing.expectEqual(csp.PolicyDisposition.report, policy.disposition);
    }
}
