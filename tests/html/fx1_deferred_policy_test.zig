//! Fetch 4.12.1 registers the two deferred-fetch policy-controlled features.
const std = @import("std");
const policy = @import("html_core").permissions_policy;

fn feature(name: []const u8) !policy.Feature {
    return policy.Feature.fromString(name) orelse error.MissingDeferredFetchFeature;
}

test "deferred-fetch policy names and default allowlists" {
    const full = try feature("deferred-fetch");
    const minimal = try feature("deferred-fetch-minimal");
    try std.testing.expectEqualStrings("deferred-fetch", full.toString());
    try std.testing.expectEqualStrings("deferred-fetch-minimal", minimal.toString());
    try std.testing.expectEqual(policy.DefaultAllowlist.self_origin, full.defaultAllowlist());
    try std.testing.expectEqual(policy.DefaultAllowlist.all, minimal.defaultAllowlist());
    var permissions = try policy.PermissionsPolicy.init(std.testing.allocator, "https://parent.test");
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(full, "https://parent.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(full, "https://child.test"));
    try std.testing.expect(permissions.isFeatureAllowed(minimal, "https://child.test"));
}

test "Permissions-Policy header can delegate full quota and disable minimal quota" {
    const full = try feature("deferred-fetch");
    const minimal = try feature("deferred-fetch-minimal");
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "deferred-fetch=(self \"https://child.test\"), deferred-fetch-minimal=()",
        "https://parent.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(full, "https://parent.test"));
    try std.testing.expect(permissions.isFeatureAllowed(full, "https://child.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(full, "https://other.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(minimal, "https://parent.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(minimal, "https://child.test"));
}

test "iframe allow recognizes both deferred-fetch features" {
    const full = try feature("deferred-fetch");
    const minimal = try feature("deferred-fetch-minimal");
    var permissions = try policy.PermissionsPolicy.fromAllowAttribute(
        std.testing.allocator,
        "deferred-fetch 'src'; deferred-fetch-minimal *",
        "https://parent.test",
        "https://child.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(full, "https://child.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(full, "https://other.test"));
    try std.testing.expect(permissions.isFeatureAllowed(minimal, "https://other.test"));
}

test "Permissions-Policy rejects a malformed structured field as a whole" {
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "camera=(), broken=(\"unterminated)",
        "https://parent.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowedForSelf(.camera));
}

test "Permissions-Policy duplicate header keys take the last structured value" {
    var permissions = try policy.PermissionsPolicy.fromHeader(
        std.testing.allocator,
        "camera=(\"https://first.test\"), camera=(self)",
        "https://parent.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowedForSelf(.camera));
    try std.testing.expect(!permissions.isFeatureAllowed(.camera, "https://first.test"));
}

test "iframe allow's first declaration wins and self is the container origin" {
    var permissions = try policy.PermissionsPolicy.fromAllowAttribute(
        std.testing.allocator,
        "camera 'self'; camera *",
        "https://parent.test",
        "https://child.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(.camera, "https://parent.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.camera, "https://child.test"));
}

test "an opaque origin cannot be matched by its null serialization" {
    var allowlist = policy.Allowlist.allowSelf(std.testing.allocator);
    defer allowlist.deinit();
    try std.testing.expect(!allowlist.isAllowed("null", "null"));
}

test "policy header and attribute parsing unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsingAllocationCase, .{});
}

fn parsingAllocationCase(allocator: std.mem.Allocator) !void {
    var header = try policy.PermissionsPolicy.fromHeader(
        allocator,
        "camera=(self \"https://first.test\"), camera=(\"https://child.test\");report-to=endpoint",
        "https://parent.test",
    );
    defer header.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttribute(
        allocator,
        "camera 'self' https://child.test; camera *; microphone 'src'",
        "https://parent.test",
        "https://child.test",
    );
    defer container.deinit();
}

const origins = @import("dom").origin_record;

test "document policy reports an enforce violation with its report-to endpoint" {
    const origin = try origins.OriginRecord.create(std.testing.allocator, "https://parent.test");
    defer origin.release();
    var policies = try policy.Policies.fromHeaders(std.testing.allocator, origin, null, null, .{
        .enforce = "deferred-fetch=();report-to=denied",
    });
    defer policies.deinit();
    const result = try policies.check(.deferred_fetch, .{ .serialized = "https://parent.test", .record = origin });
    try std.testing.expect(!result.enabled);
    const violation = result.violation orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(policy.Disposition.enforce, violation.disposition);
    try std.testing.expectEqualStrings("denied", violation.endpoint.?);
}

test "report-only policy reports without disabling the feature" {
    const origin = try origins.OriginRecord.create(std.testing.allocator, "https://parent.test");
    defer origin.release();
    var policies = try policy.Policies.fromHeaders(std.testing.allocator, origin, null, null, .{
        .report_only = "deferred-fetch=();report-to=observe",
    });
    defer policies.deinit();
    const result = try policies.check(.deferred_fetch, .{ .serialized = "https://parent.test", .record = origin });
    try std.testing.expect(result.enabled);
    const violation = result.violation orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(policy.Disposition.report, violation.disposition);
    try std.testing.expectEqualStrings("observe", violation.endpoint.?);
}

test "enforce reporting wins over report-only and report-to must be a token" {
    const origin = try origins.OriginRecord.create(std.testing.allocator, "https://parent.test");
    defer origin.release();
    var policies = try policy.Policies.fromHeaders(std.testing.allocator, origin, null, null, .{
        .enforce = "deferred-fetch=();report-to=old;report-to=\"not-a-token\"",
        .report_only = "deferred-fetch=();report-to=observe",
    });
    defer policies.deinit();
    const result = try policies.check(.deferred_fetch, .{ .serialized = "https://parent.test", .record = origin });
    try std.testing.expect(!result.enabled);
    const violation = result.violation orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(policy.Disposition.enforce, violation.disposition);
    try std.testing.expect(violation.endpoint == null);
}

test "scalar and inner-list header origins have the same permissions policy meaning" {
    for ([_][]const u8{ "camera=\"https://child.test\"", "camera=(\"https://child.test\")" }) |header| {
        var permissions = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, header, "https://parent.test");
        defer permissions.deinit();
        try std.testing.expect(permissions.isFeatureAllowed(.camera, "https://child.test"));
        try std.testing.expect(!permissions.isFeatureAllowedForSelf(.camera));
    }
}

test "invalid and unmatchable header ports never grant the default port" {
    for ([_][]const u8{ "camera=(\"https://child.test:notaport\")", "camera=(\"https://child.test:65536\")" }) |header| {
        var permissions = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, header, "https://parent.test");
        defer permissions.deinit();
        try std.testing.expect(!permissions.isFeatureAllowed(.camera, "https://child.test"));
    }
}

test "inherited policy applies container defaults separately from parent feature values" {
    const allocator = std.testing.allocator;
    const origin = try origins.OriginRecord.create(allocator, "https://child.test");
    defer origin.release();
    var parent = try policy.PermissionsPolicy.init(allocator, "https://parent.test");
    defer parent.deinit();
    var child = try policy.PermissionsPolicy.fromNavigable(allocator, origin, &parent, null, null);
    defer child.deinit();
    try std.testing.expect(!child.isFeatureAllowedForSelf(.deferred_fetch));
    try std.testing.expect(child.isFeatureAllowedForSelf(.deferred_fetch_minimal));
    var container = try policy.PermissionsPolicy.fromAllowAttribute(allocator, "deferred-fetch 'src'", "https://parent.test", "https://child.test");
    defer container.deinit();
    var delegated = try policy.PermissionsPolicy.fromNavigable(allocator, origin, &parent, &container, null);
    defer delegated.deinit();
    try std.testing.expect(delegated.isFeatureAllowedForSelf(.deferred_fetch));
}

test "an explicit parent restriction cannot be widened by a container or child header" {
    const allocator = std.testing.allocator;
    const origin = try origins.OriginRecord.create(allocator, "https://child.test");
    defer origin.release();
    var parent = try policy.PermissionsPolicy.fromHeader(allocator, "deferred-fetch=(self)", "https://parent.test");
    defer parent.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttribute(allocator, "deferred-fetch *", "https://parent.test", "https://child.test");
    defer container.deinit();
    var child = try policy.PermissionsPolicy.fromNavigable(allocator, origin, &parent, &container, "deferred-fetch=*");
    defer child.deinit();
    try std.testing.expect(!child.isFeatureAllowedForSelf(.deferred_fetch));
}

test "a child owns its inherited bits after the parent policy is destroyed" {
    const allocator = std.testing.allocator;
    const origin = try origins.OriginRecord.create(allocator, "https://parent.test");
    defer origin.release();
    var child: policy.PermissionsPolicy = undefined;
    {
        var parent = try policy.PermissionsPolicy.fromHeader(allocator, "deferred-fetch=()", "https://parent.test");
        defer parent.deinit();
        child = try policy.PermissionsPolicy.fromNavigable(allocator, origin, &parent, null, null);
    }
    defer child.deinit();
    try std.testing.expect(!child.isFeatureAllowedForSelf(.deferred_fetch));
    try std.testing.expect(child.isFeatureAllowedForSelf(.deferred_fetch_minimal));
}

test "container origins are URL parsed and credentials and blob URLs are ignored" {
    var permissions = try policy.PermissionsPolicy.fromAllowAttribute(
        std.testing.allocator,
        "camera https://child.test:443/path?q https://user@ignored.test blob:https://blob.test/id",
        "https://parent.test",
        "https://child.test",
    );
    defer permissions.deinit();
    try std.testing.expect(permissions.isFeatureAllowed(.camera, "https://child.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.camera, "https://ignored.test"));
    try std.testing.expect(!permissions.isFeatureAllowed(.camera, "https://blob.test"));
}

test "self and src declarations preserve opaque identity and retained origin records" {
    const opaque_record = try origins.OriginRecord.create(std.testing.allocator, "null");
    defer opaque_record.release();
    const other = try origins.OriginRecord.create(std.testing.allocator, "null");
    defer other.release();
    var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(std.testing.allocator, "deferred-fetch 'src'; deferred-fetch-minimal 'self'", opaque_record, opaque_record);
    defer container.deinit();
    const own: origins.Origin = .{ .serialized = "null", .record = opaque_record };
    const distinct: origins.Origin = .{ .serialized = "null", .record = other };
    try std.testing.expect(container.isFeatureAllowedForOrigin(.deferred_fetch, own));
    try std.testing.expect(container.isFeatureAllowedForOrigin(.deferred_fetch_minimal, own));
    try std.testing.expect(!container.isFeatureAllowedForOrigin(.deferred_fetch, distinct));
    try std.testing.expect(!container.isFeatureAllowedForOrigin(.deferred_fetch_minimal, distinct));
    try std.testing.expect(!container.isFeatureAllowed(.deferred_fetch, "null"));
}

test "declared self uses origin-domain while the inherited default uses same-origin" {
    const parent_origin = try origins.OriginRecord.create(std.testing.allocator, "https://a.example.test");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.create(std.testing.allocator, "https://b.example.test");
    defer child_origin.release();
    try parent_origin.setDomain("example.test");
    try child_origin.setDomain("example.test");
    var parent = policy.PermissionsPolicy.initWithOrigin(std.testing.allocator, parent_origin);
    defer parent.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(std.testing.allocator, "deferred-fetch 'self'", parent_origin, child_origin);
    defer container.deinit();
    const child: origins.Origin = .{ .serialized = "https://b.example.test", .record = child_origin };
    try std.testing.expect(!policy.PermissionsPolicy.inheritedValue(.deferred_fetch, &parent, null, child));
    try std.testing.expect(policy.PermissionsPolicy.inheritedValue(.deferred_fetch, &parent, &container, child));
}

test "header origins use the existing CSP wildcard scheme and port matching" {
    var parsed = try policy.PermissionsPolicy.fromHeader(std.testing.allocator, "deferred-fetch=(\"https://*.example.test:*\")", "https://parent.test");
    defer parsed.deinit();
    try std.testing.expect(parsed.isFeatureAllowed(.deferred_fetch, "https://child.example.test:8443"));
    try std.testing.expect(!parsed.isFeatureAllowed(.deferred_fetch, "https://example.test"));
    try std.testing.expect(!parsed.isFeatureAllowed(.deferred_fetch, "https://notexample.test"));
    try std.testing.expect(!parsed.isFeatureAllowed(.deferred_fetch, "http://child.example.test"));
}

test "owned enforcing and report-only policy pairs unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, pairAllocationCase, .{});
}

fn pairAllocationCase(allocator: std.mem.Allocator) !void {
    const parent_origin = try origins.OriginRecord.create(allocator, "https://parent.test");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.create(allocator, "https://child.test");
    defer child_origin.release();
    var parent = try policy.Policies.fromHeaders(allocator, parent_origin, null, null, .{
        .enforce = "deferred-fetch=*;report-to=parent",
        .report_only = "deferred-fetch=();report-to=observe",
    });
    defer parent.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, "deferred-fetch 'src'", parent_origin, child_origin);
    defer container.deinit();
    var child = try policy.Policies.fromHeaders(allocator, child_origin, &parent, &container, .{
        .enforce = "deferred-fetch=(self \"https://other.test\");report-to=child",
        .report_only = "deferred-fetch=(\"https://other.test\");report-to=observe-child",
    });
    defer child.deinit();
}

test "response policy headers are combined, owned and allocation-failure safe" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, responseHeadersCase, .{});
}

fn responseHeadersCase(allocator: std.mem.Allocator) !void {
    const response = try @import("fetch").internal.InternalResponse.init(allocator);
    defer response.deinit();
    try response.header_list.append("Permissions-Policy", "deferred-fetch=()");
    try response.header_list.append("Permissions-Policy", "deferred-fetch-minimal=*");
    try response.header_list.append("Permissions-Policy-Report-Only", "deferred-fetch=();report-to=observe");
    var headers = try policy.OwnedHeaders.fromResponse(allocator, response);
    defer headers.deinit();
    try std.testing.expectEqualStrings("deferred-fetch=(), deferred-fetch-minimal=*", headers.values.enforce.?);
    try std.testing.expectEqualStrings("deferred-fetch=();report-to=observe", headers.values.report_only.?);
}

test "a child report-only policy inherits the parent's enforced feature values" {
    const origin = try origins.OriginRecord.create(std.testing.allocator, "https://parent.test");
    defer origin.release();
    for ([_]bool{ false, true }) |enforced_allows| {
        var parent = try policy.Policies.fromHeaders(std.testing.allocator, origin, null, null, .{
            .enforce = if (enforced_allows) "deferred-fetch=*" else "deferred-fetch=()",
            .report_only = if (enforced_allows) "deferred-fetch=()" else "deferred-fetch=*",
        });
        defer parent.deinit();
        // §9.6.1 -> §9.5.3 -> §9.7 with its default report-only=false,
        // even when §9.6 subsequently parses the Report-Only header.
        var child = try policy.Policies.fromHeaders(std.testing.allocator, origin, &parent, null, .{});
        defer child.deinit();
        try std.testing.expectEqual(enforced_allows, child.enforce.isFeatureAllowedForSelf(.deferred_fetch));
        try std.testing.expectEqual(enforced_allows, child.report_only.isFeatureAllowedForSelf(.deferred_fetch));
    }
}

test "an unresolved child captures allow and survives parent policy destruction" {
    try lazyPolicyCase(std.testing.allocator);
}

test "lazy policy capture and resolution unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, lazyPolicyCase, .{});
}

fn lazyPolicyCase(allocator: std.mem.Allocator) !void {
    const parent_origin = try origins.OriginRecord.create(allocator, "https://parent.test");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.createOwn(allocator);
    defer child_origin.release();
    var child: policy.Policies = undefined;
    {
        var parent = try policy.Policies.fromHeaders(allocator, parent_origin, null, null, .{
            .enforce = "deferred-fetch=*",
        });
        defer parent.deinit();
        var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, "deferred-fetch 'none'", parent_origin, child_origin);
        defer container.deinit();
        child = try policy.Policies.fromHeaders(allocator, child_origin, &parent, &container, .{
            .enforce = "deferred-fetch=*;report-to=captured",
            .report_only = "deferred-fetch=*;report-to=observed",
        });
    }
    defer child.deinit();
    try child_origin.resolve("https://child.test");
    const answer = try child.check(.deferred_fetch, .{ .serialized = child_origin.serialized.?, .record = child_origin });
    try std.testing.expect(!answer.enabled);
    try std.testing.expectEqualStrings("captured", answer.violation.?.endpoint.?);
    // §9.6.3 omits declarations disabled by inheritance. Completing lazy
    // construction must match eager construction, while §9.6.4 retains
    // both reporting configurations.
    try std.testing.expect(!child.enforce.declared_policy.contains(.deferred_fetch));
    try std.testing.expect(!child.report_only.declared_policy.contains(.deferred_fetch));
    try std.testing.expectEqualStrings("observed", child.report_only.reporting.get(.deferred_fetch).?);
    // Resolving twice does not resurrect or retain the consumed snapshot.
    try std.testing.expect(!(try child.check(.deferred_fetch, .{ .serialized = child_origin.serialized.?, .record = child_origin })).enabled);
}

test "lazy inherited policy freezes origin-domain values at construction" {
    const allocator = std.testing.allocator;
    const parent_origin = try origins.OriginRecord.create(allocator, "https://a.example.test");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.createOwn(allocator);
    defer child_origin.release();
    var parent = try policy.Policies.fromHeaders(allocator, parent_origin, null, null, .{ .enforce = "deferred-fetch=(self)" });
    defer parent.deinit();
    var container = try policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, "deferred-fetch *", parent_origin, child_origin);
    defer container.deinit();
    var child = try policy.Policies.fromHeaders(allocator, child_origin, &parent, &container, .{});
    defer child.deinit();
    try parent_origin.setDomain("example.test");
    try child_origin.setDomain("example.test");
    try child_origin.resolve("https://b.example.test");
    // Had §9.7 run with the construction-time domain values, the parent's
    // self declaration would not have admitted the child's different origin.
    const answer = try child.check(.deferred_fetch, .{ .serialized = child_origin.serialized.?, .record = child_origin });
    try std.testing.expect(!answer.enabled);
}

test "an unresolved policy snapshot can be destroyed without resolving" {
    const allocator = std.testing.allocator;
    const parent_origin = try origins.OriginRecord.create(allocator, "https://parent.test");
    defer parent_origin.release();
    const child_origin = try origins.OriginRecord.createOwn(allocator);
    defer child_origin.release();
    var parent = policy.Policies.init(allocator, parent_origin);
    defer parent.deinit();
    var child = try policy.Policies.fromHeaders(allocator, child_origin, &parent, null, .{});
    defer child.deinit();
}

fn ownedHeaderValues(allocator: std.mem.Allocator) !void {
    var enforcing = [_]u8{'*'};
    var reporting = [_]u8{'*'};
    var headers = try policy.OwnedHeaders.fromValues(allocator, .{ .enforce = &enforcing, .report_only = &reporting });
    defer headers.deinit();
    enforcing[0] = '!';
    reporting[0] = '!';
    try std.testing.expectEqualStrings("*", headers.values.enforce.?);
    try std.testing.expectEqualStrings("*", headers.values.report_only.?);
}

test "navigation header handoff copies both values and cleans every allocation failure" {
    try ownedHeaderValues(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, ownedHeaderValues, .{});
}
