//! Lane coi1: HTML's embedder and opener policies obtained from response
//! headers (7.1.3.1, 7.1.4.1), their place in the policy container, and
//! Fetch's cross-origin resource policy check (3.7).

const std = @import("std");
const fetch = @import("fetch");
const policies = fetch.internal.cross_origin_policies;
const structured_fields = fetch.internal.structured_fields;
const Container = fetch.internal.PolicyContainer;

const testing = std.testing;

test "parseItemToken: a token item and its last report-to String" {
    const a = testing.allocator;
    {
        const item = try structured_fields.parseItemToken(a, "same-origin; report-to=\"endpoint\"");
        defer if (item.report_to) |e| a.free(e);
        try testing.expectEqualStrings("same-origin", item.token.?);
        try testing.expectEqualStrings("endpoint", item.report_to.?);
    }
    {
        // A later report-to of another type overwrites the String.
        const item = try structured_fields.parseItemToken(a, "require-corp;report-to=\"a\";report-to=b");
        try testing.expect(item.report_to == null);
        try testing.expectEqualStrings("require-corp", item.token.?);
    }
    {
        // A String item is not a token.
        const item = try structured_fields.parseItemToken(a, "\"same-origin\"");
        try testing.expect(item.token == null);
    }
    // Two combined headers are a list, not an item.
    try testing.expectError(error.InvalidField, structured_fields.parseItemToken(a, "same-origin, same-origin"));
    try testing.expectError(error.InvalidField, structured_fields.parseItemToken(a, "same-origin unsafe-allow-outgoing"));
    try testing.expectError(error.InvalidField, structured_fields.parseItemToken(a, "same-orig\xc3\xa9n"));
}

test "obtain an embedder policy: HTML 7.1.4.1's table, fail-open on anything but one compatible token" {
    const a = testing.allocator;
    const Case = struct { header: ?[]const u8, value: policies.EmbedderPolicyValue };
    const cases = [_]Case{
        .{ .header = null, .value = .unsafe_none },
        .{ .header = "require-corp", .value = .require_corp },
        .{ .header = "unknown-value", .value = .unsafe_none },
        .{ .header = "require-corp, unknown-value", .value = .unsafe_none },
        .{ .header = "unknown-value, unknown-value", .value = .unsafe_none },
        .{ .header = "unknown-value, require-corp", .value = .unsafe_none },
        .{ .header = "require-corp, require-corp", .value = .unsafe_none },
        .{ .header = "credentialless", .value = .credentialless },
        .{ .header = "unsafe-none", .value = .unsafe_none },
        .{ .header = "Require-Corp", .value = .unsafe_none },
        .{ .header = "\"require-corp\"", .value = .unsafe_none },
        .{ .header = "require-corp;foo=bar", .value = .require_corp },
        // RFC 9651 4.2 steps 2 and 6 discard leading and trailing SP.
        .{ .header = " require-corp ", .value = .require_corp },
        .{ .header = "\trequire-corp", .value = .unsafe_none },
        .{ .header = "require-corp ", .value = .require_corp },
    };
    for (cases) |case| {
        var policy = try policies.obtainEmbedderPolicy(a, .{ .coep = case.header }, true);
        defer policy.deinit(a);
        testing.expectEqual(case.value, policy.value) catch |err| {
            std.debug.print("header {?s}\n", .{case.header});
            return err;
        };
        // The same rules for the report-only header, independently.
        var report_only = try policies.obtainEmbedderPolicy(a, .{ .coep_report_only = case.header }, true);
        defer report_only.deinit(a);
        try testing.expectEqual(case.value, report_only.report_only_value);
        try testing.expectEqual(policies.EmbedderPolicyValue.unsafe_none, report_only.value);
    }
}

test "obtain an embedder policy: endpoints, and a non-secure environment gets a new policy" {
    const a = testing.allocator;
    var policy = try policies.obtainEmbedderPolicy(a, .{
        .coep = "require-corp; report-to=\"enforce\"",
        .coep_report_only = "credentialless; report-to=\"report\"",
    }, true);
    defer policy.deinit(a);
    try testing.expectEqual(policies.EmbedderPolicyValue.require_corp, policy.value);
    try testing.expectEqualStrings("enforce", policy.reporting_endpoint);
    try testing.expectEqual(policies.EmbedderPolicyValue.credentialless, policy.report_only_value);
    try testing.expectEqualStrings("report", policy.report_only_reporting_endpoint);

    // A report-to for an incompatible value is not kept.
    var ignored = try policies.obtainEmbedderPolicy(a, .{ .coep = "unsafe-none; report-to=\"x\"" }, true);
    defer ignored.deinit(a);
    try testing.expectEqualStrings("", ignored.reporting_endpoint);

    var insecure = try policies.obtainEmbedderPolicy(a, .{ .coep = "require-corp; report-to=\"x\"" }, false);
    defer insecure.deinit(a);
    try testing.expectEqual(policies.EmbedderPolicyValue.unsafe_none, insecure.value);
    try testing.expectEqualStrings("", insecure.reporting_endpoint);
}

test "obtain an opener policy: values, same-origin-plus-COEP, report-only and endpoints" {
    const a = testing.allocator;
    const Case = struct { coop: ?[]const u8, coep: ?[]const u8 = null, value: policies.OpenerPolicyValue };
    const cases = [_]Case{
        .{ .coop = null, .value = .unsafe_none },
        .{ .coop = "unsafe-none", .value = .unsafe_none },
        .{ .coop = "same-origin", .value = .same_origin },
        .{ .coop = "same-origin", .coep = "require-corp", .value = .same_origin_plus_coep },
        .{ .coop = "same-origin", .coep = "credentialless", .value = .same_origin_plus_coep },
        .{ .coop = "same-origin", .coep = "require-corp, require-corp", .value = .same_origin },
        .{ .coop = "same-origin-allow-popups", .coep = "require-corp", .value = .same_origin_allow_popups },
        .{ .coop = "noopener-allow-popups", .value = .noopener_allow_popups },
        .{ .coop = "same-site", .value = .unsafe_none },
        .{ .coop = "jibberish", .value = .unsafe_none },
        .{ .coop = "same-origin unsafe-allow-outgoing", .value = .unsafe_none },
        .{ .coop = "same-origin, same-origin", .value = .unsafe_none },
        .{ .coop = "same-origin; report-to=\"x\"", .value = .same_origin },
        .{ .coop = "\"same-origin\"", .value = .unsafe_none },
        .{ .coop = "same-origin-plus-coep", .value = .unsafe_none },
    };
    for (cases) |case| {
        var policy = try policies.obtainOpenerPolicy(a, .{ .coop = case.coop, .coep = case.coep }, true);
        defer policy.deinit(a);
        testing.expectEqual(case.value, policy.value) catch |err| {
            std.debug.print("coop {?s} coep {?s}\n", .{ case.coop, case.coep });
            return err;
        };
    }

    var reported = try policies.obtainOpenerPolicy(a, .{
        .coop = "same-origin-allow-popups; report-to=\"enforce\"",
        .coop_report_only = "same-origin; report-to=\"report\"",
        .coep_report_only = "require-corp",
    }, true);
    defer reported.deinit(a);
    try testing.expectEqual(policies.OpenerPolicyValue.same_origin_allow_popups, reported.value);
    try testing.expectEqualStrings("enforce", reported.reporting_endpoint.?);
    // 6.1.2: report-only COOP considers report-only COEP too.
    try testing.expectEqual(policies.OpenerPolicyValue.same_origin_plus_coep, reported.report_only_value);
    try testing.expectEqualStrings("report", reported.report_only_reporting_endpoint.?);

    // The report-only header has no noopener-allow-popups step.
    var no_ro = try policies.obtainOpenerPolicy(a, .{ .coop_report_only = "noopener-allow-popups" }, true);
    defer no_ro.deinit(a);
    try testing.expectEqual(policies.OpenerPolicyValue.unsafe_none, no_ro.report_only_value);

    var insecure = try policies.obtainOpenerPolicy(a, .{ .coop = "same-origin", .coep = "require-corp" }, false);
    defer insecure.deinit(a);
    try testing.expectEqual(policies.OpenerPolicyValue.unsafe_none, insecure.value);
}

test "a response with no COOP/COEP headers allocates nothing in the policy path" {
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    const a = failing.allocator();
    var coep = try policies.obtainEmbedderPolicy(a, .{}, true);
    defer coep.deinit(a);
    var coop = try policies.obtainOpenerPolicy(a, .{}, true);
    defer coop.deinit(a);
    // Headers without endpoints allocate nothing either.
    var coep2 = try policies.obtainEmbedderPolicy(a, .{ .coep = "require-corp", .coep_report_only = "credentialless" }, true);
    defer coep2.deinit(a);
    var coop2 = try policies.obtainOpenerPolicy(a, .{ .coop = "same-origin", .coep = "require-corp" }, true);
    defer coop2.deinit(a);
    var copy = try coep2.clone(a);
    defer copy.deinit(a);
    try testing.expectEqual(@as(usize, 0), failing.allocations);
}

fn obtainBoth(a: std.mem.Allocator) !void {
    var coep = try policies.obtainEmbedderPolicy(a, .{
        .coep = "require-corp; report-to=\"a\"",
        .coep_report_only = "credentialless; report-to=\"b\"",
    }, true);
    defer coep.deinit(a);
    var copy = try coep.clone(a);
    defer copy.deinit(a);
    var coop = try policies.obtainOpenerPolicy(a, .{
        .coop = "same-origin; report-to=\"c\"",
        .coop_report_only = "same-origin-allow-popups; report-to=\"d\"",
        .coep = "require-corp; report-to=\"a\"",
    }, true);
    defer coop.deinit(a);
    var coop_copy = try coop.clone(a);
    defer coop_copy.deinit(a);
}

test "obtaining and cloning policies with endpoints survives every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, obtainBoth, .{});
}

test "the policy container: the response's embedder policy, cloned; the opener policy is not inherited" {
    const a = testing.allocator;
    var container = try Container.fromResponseHeaders(a, .{
        .url = "https://a.test/",
        .coep = "require-corp; report-to=\"e\"",
        .environment_secure = true,
    });
    defer container.deinit();
    try testing.expectEqual(policies.EmbedderPolicyValue.require_corp, container.embedderPolicy().value);
    try container.setOpenerPolicy(try policies.obtainOpenerPolicy(a, .{ .coop = "same-origin; report-to=\"o\"", .coep = "require-corp" }, true));
    var copy = try container.clone(a);
    defer copy.deinit();
    try testing.expectEqual(policies.EmbedderPolicyValue.require_corp, copy.embedderPolicy().value);
    try testing.expectEqualStrings("e", copy.embedderPolicy().reporting_endpoint);
    try testing.expectEqual(policies.OpenerPolicyValue.unsafe_none, copy.openerPolicy().value);
    try testing.expect(copy.openerPolicy().reporting_endpoint == null);

    // No environment: unsafe-none, whatever the response says.
    var no_env = try Container.fromResponseHeaders(a, .{ .url = "https://a.test/", .coep = "require-corp" });
    defer no_env.deinit();
    try testing.expectEqual(policies.EmbedderPolicyValue.unsafe_none, no_env.embedderPolicy().value);
    // A non-secure environment: unsafe-none.
    var insecure = try Container.fromResponseHeaders(a, .{ .url = "http://a.test/", .coep = "require-corp", .environment_secure = false });
    defer insecure.deinit();
    try testing.expectEqual(policies.EmbedderPolicyValue.unsafe_none, insecure.embedderPolicy().value);
}

fn cloneWithPolicies(a: std.mem.Allocator) !void {
    var container = try Container.fromResponseHeaders(a, .{
        .url = "https://a.test/",
        .coep = "credentialless; report-to=\"e\"",
        .coep_report_only = "require-corp; report-to=\"r\"",
        .environment_secure = true,
    });
    defer container.deinit();
    var copy = try container.clone(a);
    defer copy.deinit();
}

test "a container with embedder policy endpoints survives every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, cloneWithPolicies, .{});
}

test "cross-origin resource policy internal check: Fetch 3.7's table" {
    const a = testing.allocator;
    const E = policies.EmbedderPolicyValue;
    const Case = struct {
        origin: []const u8,
        url: []const u8,
        corp: ?[]const u8,
        coep: E = .unsafe_none,
        credentials: bool = true,
        navigation: bool = false,
        result: policies.CorpResult,
    };
    const cases = [_]Case{
        // No header, no embedder policy: allowed.
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = null, .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "cross-origin", .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "same-origin", .result = .blocked },
        .{ .origin = "https://a.test", .url = "https://a.test/x", .corp = "same-origin", .result = .allowed },
        // same-site: schemelessly same site, and a secure response needs a
        // secure requesting origin.
        .{ .origin = "https://www.a.test", .url = "https://cdn.a.test/x", .corp = "same-site", .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "same-site", .result = .blocked },
        .{ .origin = "http://www.a.test", .url = "https://cdn.a.test/x", .corp = "same-site", .result = .blocked },
        .{ .origin = "https://www.a.test", .url = "http://cdn.a.test/x", .corp = "same-site", .result = .allowed },
        // Unknown and combined values are null.
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "same-site, same-origin", .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "SAME-ORIGIN", .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "same-origin", .coep = .require_corp, .result = .blocked },
        // require-corp makes a missing header same-origin.
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = null, .coep = .require_corp, .result = .blocked },
        .{ .origin = "https://a.test", .url = "https://a.test/x", .corp = null, .coep = .require_corp, .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "cross-origin", .coep = .require_corp, .result = .allowed },
        // credentialless: only a credentialed response (or a navigation).
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = null, .coep = .credentialless, .credentials = false, .result = .allowed },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = null, .coep = .credentialless, .credentials = true, .result = .blocked },
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = null, .coep = .credentialless, .credentials = false, .navigation = true, .result = .blocked },
        // A navigation under unsafe-none is always allowed.
        .{ .origin = "https://a.test", .url = "https://b.test/x", .corp = "same-origin", .navigation = true, .result = .allowed },
        // An opaque requesting origin is same origin with nothing.
        .{ .origin = "null", .url = "https://b.test/x", .corp = "same-origin", .result = .blocked },
        .{ .origin = "null", .url = "https://b.test/x", .corp = "same-site", .result = .blocked },
    };
    for (cases) |case| {
        const result = try policies.corpInternalCheck(a, case.origin, case.coep, .{
            .url = case.url,
            .corp = case.corp,
            .request_includes_credentials = case.credentials,
        }, case.navigation);
        testing.expectEqual(case.result, result) catch |err| {
            std.debug.print("{s} -> {s} corp {?s} coep {s}\n", .{ case.origin, case.url, case.corp, @tagName(case.coep) });
            return err;
        };
    }
}

test "cross-origin resource policy check: which block reports, and how" {
    const a = testing.allocator;
    const response: policies.CorpResponse = .{ .url = "https://b.test/x", .corp = null, .request_includes_credentials = true };
    // The header alone blocks: no embedder policy report.
    const header_block = try policies.corpCheck(a, "https://a.test", &.{ .value = .require_corp }, .{ .url = "https://b.test/x", .corp = "same-origin", .request_includes_credentials = true }, false);
    try testing.expectEqual(policies.CorpResult.blocked, header_block.result);
    try testing.expect(!header_block.enforced_by_embedder_policy);
    // require-corp blocks a missing header: an "enforce" report.
    const enforced = try policies.corpCheck(a, "https://a.test", &.{ .value = .require_corp }, response, false);
    try testing.expectEqual(policies.CorpResult.blocked, enforced.result);
    try testing.expect(enforced.enforced_by_embedder_policy);
    // Report-only require-corp: allowed, with a "reporting" report.
    const report_only = try policies.corpCheck(a, "https://a.test", &.{ .report_only_value = .require_corp }, response, false);
    try testing.expectEqual(policies.CorpResult.allowed, report_only.result);
    try testing.expect(report_only.report_only_blocks);
    // Nothing at all.
    const none = try policies.corpCheck(a, "https://a.test", &.{}, response, false);
    try testing.expectEqual(policies.CorpResult.allowed, none.result);
    try testing.expect(!none.report_only_blocks and !none.enforced_by_embedder_policy);
}

test "Cross-Origin-Embedder-Policy allows credentials" {
    const a = testing.allocator;
    // Not no-cors, or no client, or not credentialless: true.
    try testing.expect(try policies.coepAllowsCredentials(a, false, .credentialless, "https://a.test", "https://b.test/", true));
    try testing.expect(try policies.coepAllowsCredentials(a, true, null, "https://a.test", "https://b.test/", true));
    try testing.expect(try policies.coepAllowsCredentials(a, true, .require_corp, "https://a.test", "https://b.test/", true));
    // credentialless: only a same-origin, same-origin-tainted request.
    try testing.expect(try policies.coepAllowsCredentials(a, true, .credentialless, "https://a.test", "https://a.test/x", true));
    try testing.expect(!try policies.coepAllowsCredentials(a, true, .credentialless, "https://a.test", "https://a.test/x", false));
    try testing.expect(!try policies.coepAllowsCredentials(a, true, .credentialless, "https://a.test", "https://b.test/x", true));
}

test "a container whose response sent no COOP/COEP keeps its policies inline: nothing allocated" {
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    const a = failing.allocator();
    var container = Container.init(a);
    defer container.deinit();
    try container.setEmbedderPolicy(try policies.obtainEmbedderPolicy(a, .{}, true));
    try container.setOpenerPolicy(try policies.obtainOpenerPolicy(a, .{}, true));
    try testing.expect(container.cross_origin == null);
    var copy = try container.clone(a);
    defer copy.deinit();
    try testing.expect(copy.cross_origin == null);
    try testing.expectEqual(@as(usize, 0), failing.allocations);
}

test "setting a policy back to a new one frees the out-of-line block; a failed set releases what it took" {
    const a = testing.allocator;
    var container = Container.init(a);
    defer container.deinit();
    try container.setEmbedderPolicy(try policies.obtainEmbedderPolicy(a, .{ .coep = "require-corp; report-to=\"e\"" }, true));
    try testing.expect(container.cross_origin != null);
    try container.setEmbedderPolicy(.{});
    try testing.expect(container.cross_origin == null);

    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 1 });
    const f = failing.allocator();
    var other = Container.init(f);
    defer other.deinit();
    // The endpoint is allocation 0; the out-of-line block (allocation 1) fails,
    // and the endpoint the set took is released (the leak check sees it).
    const policy: policies.EmbedderPolicy = .{ .value = .require_corp, .reporting_endpoint = try f.dupe(u8, "e") };
    try testing.expectError(error.OutOfMemory, other.setEmbedderPolicy(policy));
    try testing.expect(other.cross_origin == null);
}
