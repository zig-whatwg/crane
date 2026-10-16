const std = @import("std");
const csp = @import("csp");
const ee = csp.embedded_enforcement;

fn checkSubsumes(allocator: std.mem.Allocator, required: []const u8, returned: []const []const u8, expected: bool) !void {
    var a = try csp.parseSerializedCSP(allocator, required, .header, .enforce);
    defer a.deinit();
    var b = csp.CSPList.init(allocator);
    defer b.deinit();
    for (returned) |text| {
        var policy = try csp.parseSerializedCSP(allocator, text, .header, .enforce);
        errdefer policy.deinit();
        policy.self_origin = try csp.Origin.create(allocator, "http", "example.test", 8000);
        try b.append(policy);
    }
    try std.testing.expectEqual(expected, try ee.subsumes(allocator, &a, &b));
}

test "CSPEE validates the complete serialized policy before parsing" {
    for ([_][]const u8{ "", "script-src x,y", "x%20y", "img-src x\r\nTest: injected", "img-src x\x0c", "img-src é", "img-src x; report-to", "report-uri /endpoint" }) |invalid| {
        try std.testing.expect(!try ee.isValidAttribute(std.testing.allocator, invalid, null, null));
    }
    for ([_][]const u8{ "img-src 'none'", "unknown-policy x", "  ; IMG-src\t'self'; ;", "script-src https://example.test/a?b=c" }) |valid| {
        try std.testing.expect(try ee.isValidAttribute(std.testing.allocator, valid, null, null));
    }
    var text: [4097]u8 = @splat(' ');
    @memcpy(text[0..7], "img-src");
    try std.testing.expect(try ee.isValidAttribute(std.testing.allocator, text[0..4096], null, null));
    try std.testing.expect(!try ee.isValidAttribute(std.testing.allocator, &text, null, null));
}

test "CSPEE child attribute must strengthen the parent's required policy" {
    try std.testing.expect(try ee.isValidAttribute(std.testing.allocator, "img-src 'none'; style-src 'none'", "img-src 'none'", null));
    try std.testing.expect(!try ee.isValidAttribute(std.testing.allocator, "img-src *", "img-src 'none'", null));
}

test "CSPEE intersects policies, resolves fallbacks and ignores report-only" {
    const a = std.testing.allocator;
    try checkSubsumes(a, "img-src 'none'", &.{}, false);
    try checkSubsumes(a, "unknown-policy x", &.{}, true);
    try checkSubsumes(a, "img-src 'none'", &.{"default-src 'none'"}, true);
    try checkSubsumes(a, "default-src 'none'", &.{"img-src 'none'"}, false);
    try checkSubsumes(a, "img-src 'none'", &.{ "img-src https://a.test", "img-src https://b.test" }, true);
    try checkSubsumes(a, "img-src https://a.test", &.{ "img-src https://a.test https://b.test", "img-src https://b.test" }, false);
    var required = try csp.parseSerializedCSP(a, "img-src 'none'", .header, .enforce);
    defer required.deinit();
    var returned = csp.CSPList.init(a);
    defer returned.deinit();
    var report = try csp.parseSerializedCSP(a, "img-src 'none'", .header, .report);
    errdefer report.deinit();
    try returned.append(report);
    try std.testing.expect(!try ee.subsumes(a, &required, &returned));
}

test "CSPEE compares nonces by presence but intersects by value, and hashes by identity" {
    const a = std.testing.allocator;
    try checkSubsumes(a, "style-src 'nonce-abc'", &.{"style-src 'nonce-xyz'"}, true);
    try checkSubsumes(a, "style-src 'none'", &.{ "style-src 'nonce-abc'", "style-src 'nonce-xyz'" }, true);
    try checkSubsumes(a, "style-src 'none'", &.{ "style-src 'nonce-abc'", "style-src 'nonce-abc' 'nonce-xyz'" }, false);
    try checkSubsumes(a, "script-src 'sha256-YWJj'", &.{"script-src 'sha256-YWJj'"}, true);
    try checkSubsumes(a, "script-src 'sha256-YWJj'", &.{"script-src 'sha256-ZGVm'"}, false);
    try checkSubsumes(a, "script-src 'sha256-YQ=='", &.{"script-src 'sha256-YQ'"}, true);
    try checkSubsumes(a, "script-src 'sha256-/w=='", &.{"script-src 'sha256-_w'"}, true);
    // Chromium's parser compares decoded hash bytes, including unused bits
    // in the final sextet, rather than the base64 spelling.
    try checkSubsumes(a, "script-src 'sha256-YQ'", &.{"script-src 'sha256-YR'"}, true);
}

test "CSPEE script flags and inline suppression follow the effective directive" {
    const a = std.testing.allocator;
    try checkSubsumes(a, "script-src 'none'", &.{"script-src 'unsafe-eval'"}, false);
    try checkSubsumes(a, "img-src 'none'", &.{"img-src 'unsafe-eval'"}, true);
    try checkSubsumes(a, "script-src 'nonce-abc'", &.{"script-src 'nonce-xyz' 'unsafe-inline'"}, true);
    try checkSubsumes(a, "script-src 'nonce-abc'", &.{"script-src 'unsafe-inline'"}, false);
    try checkSubsumes(a, "script-src 'strict-dynamic'", &.{"script-src 'none'"}, true);
    try checkSubsumes(a, "script-src https:", &.{"script-src 'strict-dynamic'"}, false);
    try checkSubsumes(a, "script-src 'strict-dynamic'", &.{"script-src https:"}, false);
    try checkSubsumes(a, "child-src https:", &.{"child-src https://a.test 'strict-dynamic'"}, true);
}

test "CSPEE source subsumption compares schemes hosts ports and path boundaries" {
    const a = std.testing.allocator;
    try checkSubsumes(a, "img-src http:", &.{"img-src https://a.test"}, true);
    try checkSubsumes(a, "img-src https:", &.{"img-src http://a.test"}, false);
    try checkSubsumes(a, "img-src http://*.test:*", &.{"img-src https://a.test:9000/a"}, true);
    try checkSubsumes(a, "img-src http://*.test", &.{"img-src http://test"}, false);
    try checkSubsumes(a, "img-src http://a.test:80", &.{"img-src https://a.test:443"}, true);
    try checkSubsumes(a, "img-src http://a.test", &.{"img-src http://a.test:*"}, false);
    try checkSubsumes(a, "img-src http://a.test/a/", &.{"img-src http://a.test/a/b"}, true);
    try checkSubsumes(a, "img-src http://a.test/a", &.{"img-src http://a.test/ab"}, false);
    try checkSubsumes(a, "img-src 'self'", &.{"img-src http://example.test:8000/a"}, true);
    try checkSubsumes(a, "img-src *", &.{"img-src data:"}, false);
}

test "CSPEE path comparison decodes each source once" {
    // CSP 3 path-part matching decodes each path once. Chrome 154's
    // content_security_policy.cc:511-519 and csp_source.cc:141-159,342
    // suggest a second decode during subsumption, but that source-level
    // inference is unconfirmed in a running browser. Keep this deliberate
    // until a shipping-browser probe settles both escaped-percent pairs.
    const a = std.testing.allocator;
    try checkSubsumes(a, "img-src https://a.test/a/b", &.{"img-src https://a.test/a%252Fb"}, false);
    try checkSubsumes(a, "img-src https://a.test/a%252Fb", &.{"img-src https://a.test/a%252Fb"}, true);
}

fn allocationPaths(allocator: std.mem.Allocator) !void {
    try checkSubsumes(allocator, "script-src http://*.test:* 'nonce-abc'", &.{ "script-src http://a.test 'nonce-xyz'", "script-src https://*.test 'nonce-xyz'" }, true);
    try std.testing.expect(try ee.isValidAttribute(allocator, "img-src 'none'", "img-src https:", null));
}

test "CSPEE releases every temporary on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}
