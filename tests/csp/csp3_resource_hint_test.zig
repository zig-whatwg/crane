const std = @import("std");
const csp = @import("csp");
const checks = csp.request_check;

fn policy(text: []const u8, disposition: csp.PolicyDisposition) !csp.Policy {
    const allocator = std.testing.allocator;
    var result = try csp.parsing.parseSerializedCSP(allocator, text, .header, disposition);
    errdefer result.deinit();
    result.self_origin = try csp.Origin.create(allocator, "https", "example.test", null);
    return result;
}

const hint: checks.Request = .{
    .url = .{ .scheme = "https", .host = "example.test", .path = "/asset" },
    .initiator = "prefetch",
};

test "prefetch is allowed by any fetch directive including default-src" {
    const allocator = std.testing.allocator;
    const names = [_][]const u8{
        "child-src",    "connect-src",    "font-src",   "frame-src",  "img-src",
        "manifest-src", "media-src",      "object-src", "script-src", "script-src-elem",
        "style-src",    "style-src-elem", "worker-src",
    };
    for (names) |name| {
        const text = try std.fmt.allocPrint(allocator, "default-src 'none'; {s} 'self'", .{name});
        defer allocator.free(text);
        var p = try policy(text, .enforce);
        defer p.deinit();
        try std.testing.expect(checks.doesRequestViolatePolicy(hint, &p) == null);
    }
    var default = try policy("default-src 'self'; img-src 'none'", .enforce);
    defer default.deinit();
    try std.testing.expect(checks.doesRequestViolatePolicy(hint, &default) == null);
}

test "prefetch requires a URL match and ignores non-fetch directives" {
    const blocked = [_][]const u8{
        "default-src 'none'",
        "default-src 'none'; img-src https://other.test",
        "default-src 'none'; script-src 'nonce-abc' 'strict-dynamic'",
        "default-src 'none'; script-src-attr 'self'",
        "default-src 'none'; style-src-attr 'self'",
        "default-src 'none'; base-uri 'self'; frame-ancestors 'self'",
        "default-src 'none'; prefetch-src 'self'",
        "default-src 'none'; report-uri https://example.test",
    };
    for (blocked) |text| {
        var p = try policy(text, .enforce);
        defer p.deinit();
        var request = hint;
        request.nonce = "abc";
        const violated = checks.doesRequestViolatePolicy(request, &p);
        try std.testing.expect(violated != null);
        try std.testing.expectEqualStrings("default-src", violated.?);
    }
    var no_default = try policy("img-src 'none'; connect-src 'none'; prefetch-src 'none'", .enforce);
    defer no_default.deinit();
    try std.testing.expect(checks.doesRequestViolatePolicy(hint, &no_default) == null);
}

test "prefetch source union remains per policy, and report-only does not enforce" {
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try policy("default-src 'none'; img-src 'self'", .enforce));
    try list.append(try policy("default-src 'none'; script-src 'self'", .enforce));
    try list.append(try policy("default-src 'none'", .report));
    try std.testing.expectEqual(checks.Result.allowed, checks.shouldRequestBeBlocked(&list, hint, null));
    const Capture = struct {
        count: usize = 0,
        wrong_directive: bool = false,
        fn report(context: *anyopaque, violation: checks.Violation) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.count += 1;
            self.wrong_directive = self.wrong_directive or
                !std.mem.eql(u8, violation.directive, "default-src") or
                !std.mem.eql(u8, violation.effective_directive, "default-src");
        }
    };
    var capture: Capture = .{};
    checks.reportViolationsForRequest(&list, hint, .{ .context = &capture, .report = Capture.report });
    try std.testing.expectEqual(@as(usize, 1), capture.count);
    try std.testing.expect(!capture.wrong_directive);
    try list.append(try policy("default-src 'none'", .enforce));
    try std.testing.expectEqual(checks.Result.blocked, checks.shouldRequestBeBlocked(&list, hint, null));
}

test "prefetch union uses redirect-aware URL matching and does not widen ordinary fetch" {
    var p = try policy("default-src 'none'; img-src https://example.test/allowed", .enforce);
    defer p.deinit();
    try std.testing.expect(checks.doesRequestViolatePolicy(hint, &p) != null);
    var request = hint;
    request.redirect_count = 1;
    try std.testing.expect(checks.doesRequestViolatePolicy(request, &p) == null);
    request.initiator = "";
    try std.testing.expect(checks.doesRequestViolatePolicy(request, &p) != null);
}

test "prefetch report-only checks default-src even when another source list matches" {
    var p = try policy("default-src 'none'; img-src *", .report);
    defer p.deinit();
    try std.testing.expectEqualStrings("default-src", checks.doesRequestViolatePolicy(hint, &p) orelse "allowed");
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try policy("default-src 'none'; img-src *", .report));
    try std.testing.expectEqual(checks.Result.allowed, checks.shouldRequestBeBlocked(&list, hint, null));
}
