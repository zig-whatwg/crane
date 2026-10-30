//! Permissions Policy §§4.7, 9.3; integrator probe Q33 (2026-10-27).
//! Chrome 156 is the only shipper of deferred-fetch among the three probes.
//! Its IPv6 frame-delegation failure is a divergence; IPv6 follows the spec.
const std = @import("std");
const policy = @import("html_core").permissions_policy;
const origins = @import("dom").origin_record;

const Case = struct {
    parent: []const u8 = "http://localhost:8766",
    child: []const u8 = "http://127.0.0.1:8766",
    header: ?[]const u8 = null,
    allow: []const u8,
    enabled: bool,
};

fn checkCase(allocator: std.mem.Allocator, case: Case) !void {
    const parent_origin = try origins.OriginRecord.create(allocator, case.parent);
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.create(allocator, case.child);
    defer child_origin.release();
    var parent = try policy.PermissionsPolicy.fromNavigable(allocator, parent_origin, null, null, case.header);
    defer parent.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, case.allow, parent_origin, child_origin);
    defer container.deinit();
    var child = try policy.PermissionsPolicy.fromNavigable(allocator, child_origin, &parent, &container, null);
    defer child.deinit();
    try std.testing.expectEqual(case.enabled, child.isFeatureAllowedForSelf(.deferred_fetch));
}

test "policy Q33 IPv4 listed origin matches" {
    try checkCase(std.testing.allocator, .{ .allow = "deferred-fetch http://127.0.0.1:8766", .enabled = true });
}

test "policy Q33 IPv4 scheme mismatch is blocked" {
    try checkCase(std.testing.allocator, .{ .allow = "deferred-fetch https://127.0.0.1:8766", .enabled = false });
}

test "policy Q33 IPv4 port mismatch is blocked" {
    try checkCase(std.testing.allocator, .{ .allow = "deferred-fetch http://127.0.0.1:8767", .enabled = false });
}

test "policy Q33 IPv4 other origin is blocked" {
    try checkCase(std.testing.allocator, .{ .allow = "deferred-fetch http://example.com", .enabled = false });
}

test "policy Q33 IPv4 src delegation matches" {
    try checkCase(std.testing.allocator, .{ .allow = "deferred-fetch", .enabled = true });
}

test "policy Q33 cross-origin default is blocked" {
    try checkCase(std.testing.allocator, .{ .allow = "", .enabled = false });
}

test "policy Q33 IPv4 header and src delegate together" {
    try checkCase(std.testing.allocator, .{ .header = "deferred-fetch=(self \"http://127.0.0.1:8766\")", .allow = "deferred-fetch", .enabled = true });
}

test "policy Q33 self-only header prevents IPv4 delegation" {
    try checkCase(std.testing.allocator, .{ .header = "deferred-fetch=(self)", .allow = "deferred-fetch", .enabled = false });
}

test "policy Q33 header scheme mismatch is blocked" {
    try checkCase(std.testing.allocator, .{ .header = "deferred-fetch=(self \"https://127.0.0.1:8766\")", .allow = "deferred-fetch", .enabled = false });
}

test "policy Q33 header port mismatch is blocked" {
    try checkCase(std.testing.allocator, .{ .header = "deferred-fetch=(self \"http://127.0.0.1:8767\")", .allow = "deferred-fetch", .enabled = false });
}

test "policy Q33 domain listed control matches" {
    try checkCase(std.testing.allocator, .{ .parent = "http://127.0.0.1:8766", .child = "http://localhost:8766", .allow = "deferred-fetch http://localhost:8766", .enabled = true });
}

test "policy Q33 domain other-origin control is blocked" {
    try checkCase(std.testing.allocator, .{ .parent = "http://127.0.0.1:8766", .child = "http://localhost:8766", .allow = "deferred-fetch http://example.com", .enabled = false });
}

test "policy Q33 domain src control matches" {
    try checkCase(std.testing.allocator, .{ .parent = "http://127.0.0.1:8766", .child = "http://localhost:8766", .allow = "deferred-fetch", .enabled = true });
}

test "policy Q33 same-origin self control matches" {
    try checkCase(std.testing.allocator, .{ .parent = "http://127.0.0.1:8766", .allow = "deferred-fetch 'self'", .enabled = true });
}

test "policy Q33 IPv6 listed origin follows the specification" {
    try checkCase(std.testing.allocator, .{ .child = "http://[::1]:8766", .allow = "deferred-fetch http://[::1]:8766", .enabled = true });
}

test "policy Q33 IPv6 src follows the specification" {
    try checkCase(std.testing.allocator, .{ .child = "http://[::1]:8766", .allow = "deferred-fetch", .enabled = true });
}

test "policy Q33 IPv6 header follows the specification" {
    try checkCase(std.testing.allocator, .{ .child = "http://[::1]:8766", .header = "deferred-fetch=(self \"http://[::1]:8766\")", .allow = "deferred-fetch", .enabled = true });
}

test "policy Q34 one allowlist matches exact origins and wildcard expressions independently" {
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "deferred-fetch=(\"http://127.0.0.1:8766\" \"https://*.example.test:*\")",
        "https://parent.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, "http://127.0.0.1:8766"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://127.0.0.1:8766"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "http://127.0.0.1:8767"));
    try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, "https://child.example.test:8443"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://example.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://notexample.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "http://child.example.test"));
}

test "policy exact-origin entries unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkCase, .{Case{
        .child = "http://[::1]:8766",
        .header = "deferred-fetch=(self \"http://127.0.0.1:8766\" \"http://[::1]:8766\")",
        .allow = "deferred-fetch http://127.0.0.1:8766 http://[::1]:8766",
        .enabled = true,
    }});
}

test "policy Q35 header origins reject URL-only syntax" {
    const values = [_][]const u8{
        "https://%65xample.test",
        "https://user@example.test",
        "https://example.test?query",
        "https://example.test#fragment",
        "https://[::1]?query",
        "https://[%3A%3A1]",
    };
    for (values) |value| {
        const header = try std.fmt.allocPrint(std.testing.allocator, "deferred-fetch=(\"{s}\")", .{value});
        defer std.testing.allocator.free(header);
        var permissions = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, header, "https://parent.test");
        defer permissions.deinit();
        try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://example.test"));
        try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://[::1]"));
    }
}

test "policy Q35 an explicit trailing slash keeps CSP source-expression matching" {
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "deferred-fetch=(\"http://example.test/\")",
        "https://parent.test",
    );
    defer permissions.deinit();
    // CSP source expressions permit this secure scheme upgrade; an exact
    // origin would not. The explicit path therefore distinguishes the rules.
    try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, "http://example.test"));
    try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, "https://example.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://other.test"));
}

test "policy Q35 an exact header origin does not use CSP scheme upgrading" {
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "deferred-fetch=(\"http://example.test\")",
        "https://parent.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, "http://example.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://example.test"));
}

test "policy Q35 IPv6 exact header candidates still require valid authority syntax" {
    const values = [_][]const u8{
        "https://[::1]:",
        "https://[::1]:+443",
        "https://[::1]:65536",
        "https://[::1]suffix",
        "https://user@[::1]",
        "https://[::1]\t",
        "https://[not-ipv6]",
    };
    for (values) |value| {
        const header = try std.fmt.allocPrint(std.testing.allocator, "deferred-fetch=(\"{s}\")", .{value});
        defer std.testing.allocator.free(header);
        var permissions = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, header, "https://parent.test");
        defer permissions.deinit();
        try std.testing.expect(!permissions.isFeatureAllowed(.deferred_fetch, "https://[::1]"));
    }
}

test "policy exact header entries compare canonical origins" {
    const cases = [_]struct { expression: []const u8, target: []const u8 }{
        .{ .expression = "https://EXAMPLE.test:443", .target = "https://example.test" },
        .{ .expression = "http://127.1:80", .target = "http://127.0.0.1" },
        .{ .expression = "https://[0:0:0:0:0:0:0:1]:443", .target = "https://[::1]" },
    };
    for (cases) |case| {
        const header = try std.fmt.allocPrint(std.testing.allocator, "deferred-fetch=(\"{s}\")", .{case.expression});
        defer std.testing.allocator.free(header);
        var permissions = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, header, "https://parent.test");
        defer permissions.deinit();
        try std.testing.expect(permissions.isFeatureAllowed(.deferred_fetch, case.target));
    }
}

fn lazyExactOrigin(allocator: std.mem.Allocator) !void {
    const parent_origin = try origins.OriginRecord.create(allocator, "http://parent.test:8766");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.createOwn(allocator);
    defer child_origin.release();
    var child: policy.Policies = undefined;
    {
        var parent = try policy.Policies.fromHeaders(allocator, parent_origin, null, null, .{
            .enforce = "deferred-fetch=(self \"http://127.0.0.1:8766\")",
        });
        defer parent.deinit();
        var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(
            allocator,
            "deferred-fetch http://127.0.0.1:8766",
            parent_origin,
            child_origin,
        );
        defer container.deinit();
        child = try policy.Policies.fromHeaders(allocator, child_origin, &parent, &container, .{});
    }
    defer child.deinit();
    // §§9.5–9.7: the creation-time origin entries still decide inheritance
    // after both input policies have been destroyed (liaison Q25/Q33).
    try child_origin.resolve("http://127.0.0.1:8766");
    const result = try child.check(.deferred_fetch, .{
        .serialized = child_origin.serialized.?,
        .record = child_origin,
    });
    try std.testing.expect(result.enabled);
    try std.testing.expect(result.violation == null);
}

test "lazy exact-origin inheritance survives input destruction and every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, lazyExactOrigin, .{});
}

fn extremeIPv4Policy(allocator: std.mem.Allocator) !void {
    const parent = try origins.OriginRecord.create(allocator, "https://parent.test");
    defer parent.release();
    const endpoints = [_][]const u8{ "http://0.0.0.0", "http://255.255.255.255" };
    for (endpoints, 0..) |endpoint, index| {
        const target = try origins.OriginRecord.create(allocator, endpoint);
        defer target.release();
        const attribute = try std.fmt.allocPrint(allocator, "deferred-fetch {s}", .{endpoint});
        defer allocator.free(attribute);
        var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, attribute, parent, target);
        defer container.deinit();
        try std.testing.expect(container.isFeatureAllowed(.deferred_fetch, endpoint));
        try std.testing.expect(!container.isFeatureAllowed(.deferred_fetch, endpoints[1 - index]));
        const header = try std.fmt.allocPrint(allocator, "deferred-fetch=(\"{s}\")", .{endpoint});
        defer allocator.free(header);
        var response = try policy.PermissionsPolicy.fromHeader(allocator, header, "https://parent.test");
        defer response.deinit();
        try std.testing.expect(response.isFeatureAllowed(.deferred_fetch, endpoint));
        try std.testing.expect(!response.isFeatureAllowed(.deferred_fetch, endpoints[1 - index]));
    }
}

test "policy origin parsing keeps the OOM-only contract at extreme IPv4 addresses" {
    const Result = @typeInfo(@TypeOf(policy.PermissionsPolicy.fromAllowAttributeOrigins)).@"fn".return_type.?;
    const expected_errors: []const std.builtin.Type.Error = &.{.{ .name = "OutOfMemory" }};
    const parse_errors = @typeInfo(@typeInfo(Result).error_union.error_set).error_set orelse return error.UnboundedErrorSet;
    try std.testing.expectEqualDeep(expected_errors, parse_errors);
    const ReservationResult = @typeInfo(@TypeOf(@import("dom").policy_containers.inheritedDeferredFetchPolicy)).@"fn".return_type.?;
    const reservation_errors = @typeInfo(@typeInfo(ReservationResult).error_union.error_set).error_set orelse return error.UnboundedErrorSet;
    try std.testing.expectEqualDeep(expected_errors, reservation_errors);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, extremeIPv4Policy, .{});
}
