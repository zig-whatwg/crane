//! Lane coi2: HTML 7.1.3.3's opener policy reports - the virtual browsing
//! context group ID (7.3.2), the navigation reports' bodies ("queue a
//! violation report for browsing context group switch when navigating to /
//! away from a COOP response") and their delivery through Reporting's queue
//! for an endpoint list with a URL and no settings object.

const std = @import("std");
const html_core = @import("html_core");

const testing = std.testing;
const opener_policy = html_core.navigation.opener_policy;
const BrowsingContext = html_core.BrowsingContext;
const Navigables = html_core.Navigables;

test "the virtual browsing context group ID is its own field: copied to auxiliary and child contexts, renewed by step 9.1 and a group switch" {
    const allocator = testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const opener = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer opener.deinit();
    const other = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer other.deinit();
    try testing.expect(opener.virtual_browsing_context_group_id != other.virtual_browsing_context_group_id);

    // "Create a new auxiliary browsing context and document" step 8, and
    // "create a new browsing context and document" step 5.3 for a child.
    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();
    const child = try BrowsingContext.initChild(allocator, popup);
    defer child.deinit();
    try testing.expectEqual(opener.virtual_browsing_context_group_id, popup.virtual_browsing_context_group_id);
    try testing.expectEqual(opener.virtual_browsing_context_group_id, child.virtual_browsing_context_group_id);

    // "Obtain a browsing context to use for a navigation response" step
    // 9.1: a new virtual group ID, while the real group stays the same.
    const before = popup.virtual_browsing_context_group_id;
    popup.startVirtualGroup();
    try testing.expect(popup.virtual_browsing_context_group_id != before);
    try testing.expect(popup.isInSameGroup(opener));

    // A group switch makes a new browsing context in a new group: a new
    // virtual group too (Chromium CrossOriginOpenerPolicyStatus::EnforceCOOP).
    const switched_before = popup.virtual_browsing_context_group_id;
    popup.switchGroup(.none, .empty);
    try testing.expect(popup.virtual_browsing_context_group_id != switched_before);
    try testing.expect(popup.virtual_browsing_context_group_id != opener.virtual_browsing_context_group_id);
}

test "a group holds others when another live top-level context shares it; children do not count" {
    const allocator = testing.allocator;
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();

    const top = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer top.deinit();
    const child = try BrowsingContext.initChild(allocator, top);
    defer child.deinit();
    try testing.expect(!top.groupHoldsOthers());
    const popup = try BrowsingContext.initAuxiliary(allocator, top, true);
    defer popup.deinit();
    try testing.expect(top.groupHoldsOthers());
    try testing.expect(popup.groupHoldsOthers());
    popup.close();
    try testing.expect(!top.groupHoldsOthers());
}

/// The body's string member `name`, or null for a missing or non-string one.
fn bodyString(parsed: std.json.Parsed(std.json.Value), name: []const u8) ?[]const u8 {
    const value = parsed.value.object.get(name) orelse return null;
    return switch (value) {
        .string => |text| text,
        else => null,
    };
}

const a = "https://a.test";
const b = "https://b.test";

test "sanitize a URL to send in a report: no credentials, no fragment, every scheme" {
    const cases = [_][2][]const u8{
        .{ "https://user:pass@a.test/path?query#fragment", "https://a.test/path?query" },
        .{ "https://a.test/", "https://a.test/" },
        .{ "about:blank#top", "about:blank" },
        .{ "blob:https://a.test/uuid", "blob:https://a.test/uuid" },
    };
    for (cases) |case| {
        const got = try opener_policy.sanitizeUrlForReport(testing.allocator, case[0]);
        defer testing.allocator.free(got);
        try testing.expectEqualStrings(case[1], got);
    }
}

test "navigation-to-response: the response's endpoint and value per disposition, the previous URL only when same origin" {
    const coop: opener_policy.OpenerPolicy = .{
        .value = .same_origin,
        .reporting_endpoint = "e",
        .report_only_value = .same_origin_plus_coep,
        .report_only_reporting_endpoint = "ro",
    };
    {
        const report = (try opener_policy.navigationToResponseReport(testing.allocator, coop, .enforce, "https://a.test/prev#x", a, a, "https://a.test/")).?;
        defer testing.allocator.free(report.body_json);
        try testing.expectEqualStrings("e", report.endpoint);
        const body = try std.json.parseFromSlice(std.json.Value, testing.allocator, report.body_json, .{});
        defer body.deinit();
        try testing.expectEqualStrings("enforce", bodyString(body, "disposition").?);
        try testing.expectEqualStrings("same-origin", bodyString(body, "effectivePolicy").?);
        try testing.expectEqualStrings("https://a.test/prev", bodyString(body, "previousResponseURL").?);
        try testing.expectEqualStrings("https://a.test/", bodyString(body, "referrer").?);
        try testing.expectEqualStrings("navigation-to-response", bodyString(body, "type").?);
    }
    {
        // "reporting": the report-only value, and - as Chromium's
        // QueueNavigationToCOOPReport and WebKit's
        // reportingEndpointForDisposition do - the report-only endpoint. A
        // cross-origin previous response: "" (both browsers), no referrer: "".
        const report = (try opener_policy.navigationToResponseReport(testing.allocator, coop, .reporting, "https://b.test/prev", a, b, null)).?;
        defer testing.allocator.free(report.body_json);
        try testing.expectEqualStrings("ro", report.endpoint);
        const body = try std.json.parseFromSlice(std.json.Value, testing.allocator, report.body_json, .{});
        defer body.deinit();
        try testing.expectEqualStrings("reporting", bodyString(body, "disposition").?);
        try testing.expectEqualStrings("same-origin-plus-coep", bodyString(body, "effectivePolicy").?);
        try testing.expectEqualStrings("", bodyString(body, "previousResponseURL").?);
        try testing.expectEqualStrings("", bodyString(body, "referrer").?);
    }
    // Step 1: no endpoint, no report.
    try testing.expect((try opener_policy.navigationToResponseReport(testing.allocator, .{ .value = .same_origin }, .enforce, "https://a.test/", a, a, null)) == null);
    try testing.expect((try opener_policy.navigationToResponseReport(testing.allocator, .{ .value = .same_origin, .reporting_endpoint = "e" }, .reporting, "https://a.test/", a, a, null)) == null);
}

test "navigation-from-response: the next URL when same origin or when the COOP document was the navigation's source" {
    const coop: opener_policy.OpenerPolicy = .{ .value = .same_origin_allow_popups, .reporting_endpoint = "e" };
    for ([_]struct { next_origin: []const u8, source: bool, shown: bool }{
        .{ .next_origin = a, .source = false, .shown = true },
        .{ .next_origin = b, .source = true, .shown = true },
        .{ .next_origin = b, .source = false, .shown = false },
    }) |case| {
        const report = (try opener_policy.navigationFromResponseReport(testing.allocator, coop, .enforce, "https://b.test/next?q#f", a, case.next_origin, case.source)).?;
        defer testing.allocator.free(report.body_json);
        try testing.expectEqualStrings("e", report.endpoint);
        const body = try std.json.parseFromSlice(std.json.Value, testing.allocator, report.body_json, .{});
        defer body.deinit();
        try testing.expectEqualStrings("enforce", bodyString(body, "disposition").?);
        try testing.expectEqualStrings("same-origin-allow-popups", bodyString(body, "effectivePolicy").?);
        try testing.expectEqualStrings(if (case.shown) "https://b.test/next?q" else "", bodyString(body, "nextResponseURL").?);
        try testing.expectEqualStrings("navigation-from-response", bodyString(body, "type").?);
        try testing.expect(body.value.object.get("referrer") == null);
    }
}

test "the navigation reports' host half and Reporting's queue for an endpoint list are compiled" {
    // dom.coop_reporting is reached from the navigation (HTMLIFrameElement's
    // openerPolicySwitch); referenced here so this file type-checks it alone.
    const dom = @import("dom");
    _ = &dom.coop_reporting.queueNavigationReports;
    _ = &dom.reporting.queueForEndpoint;
}
