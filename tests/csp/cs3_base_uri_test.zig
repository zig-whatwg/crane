const std = @import("std");
const csp = @import("csp");
const base_uri = csp.directives.base_uri;
const testing = std.testing;

const Reports = struct {
    values: [4]csp.violation_events.Violation = undefined,
    count: usize = 0,

    fn reporter(self: *Reports) csp.violation_events.Reporter {
        return .{ .context = self, .report = record };
    }

    fn record(context: *anyopaque, violation: *const csp.violation_events.Violation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.values[self.count] = violation.*;
        self.count += 1;
    }
};

test "base-uri report-only policies do not prohibit the base URL" {
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "base-uri 'none'", .header, .report));

    try std.testing.expect(base_uri.isBaseUriAllowedByList(&list, "https", "example.test", null, "/"));
}

test "base-uri reports every violated policy with the base URL and its disposition" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri 'none'", .header, .enforce));
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri https://allowed.test", .header, .report));
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri 'none'", .header, .enforce));
    var reports: Reports = .{};
    const base = "https://other.test/base/?query#fragment";

    try testing.expect(!base_uri.isBaseAllowed(&list, base, reports.reporter()));
    try testing.expectEqual(@as(usize, 3), reports.count);
    for (reports.values[0..reports.count], list.policies.items) |violation, policy| {
        try testing.expectEqualStrings("base-uri", violation.effective_directive);
        try testing.expectEqualStrings(base, violation.resource.url);
        try testing.expectEqual(policy.disposition, violation.policy.disposition);
        try testing.expect(violation.element == null);
        try testing.expectEqualStrings("", violation.sample);
    }
}

test "base-uri report-only violations are reported without blocking" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri 'none'", .header, .report));
    var reports: Reports = .{};
    try testing.expect(base_uri.isBaseAllowed(&list, "https://other.test/", reports.reporter()));
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqual(csp.types.PolicyDisposition.report, reports.values[0].policy.disposition);
}

test "base-uri has no default-src fallback and does not report allowed URLs" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "default-src 'none'", .header, .enforce));
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri https://allowed.test/path/", .header, .enforce));
    var reports: Reports = .{};
    try testing.expect(base_uri.isBaseAllowed(&list, "https://allowed.test/path/file?query#fragment", reports.reporter()));
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expect(!base_uri.isBaseAllowed(&list, "https://allowed.test/elsewhere", reports.reporter()));
    try testing.expectEqual(@as(usize, 1), reports.count);
}

test "base-uri preserves a policy origin when present and otherwise uses its list origin" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    list.self_origin = csp.types.Origin.createBorrowed("https", "list.test", null);
    try list.append(try csp.parseSerializedCSP(testing.allocator, "base-uri 'self'", .header, .enforce));
    try testing.expect(base_uri.isBaseAllowed(&list, "https://list.test/path", null));
    list.policies.items[0].self_origin = csp.types.Origin.createBorrowed("https", "policy.test", null);
    try testing.expect(!base_uri.isBaseAllowed(&list, "https://list.test/path", null));
    try testing.expect(base_uri.isBaseAllowed(&list, "https://policy.test/path", null));
}

test "base-uri allows an empty CSP list and fails closed for an unavailable list" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    var reports: Reports = .{};
    try testing.expect(base_uri.isBaseAllowed(&list, "https://example.test/", reports.reporter()));
    try testing.expect(!base_uri.isBaseAllowed(&csp.CSPList.unavailable, "https://example.test/", reports.reporter()));
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "base-uri self falls back to the CSP list origin" {
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    list.self_origin = csp.types.Origin.createBorrowed("https", "example.test", null);
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "base-uri 'self'", .header, .enforce));

    try std.testing.expect(base_uri.isBaseUriAllowedByList(&list, "https", "example.test", null, "/"));
    try std.testing.expect(!base_uri.isBaseUriAllowedByList(&list, "https", "other.test", null, "/"));
}
