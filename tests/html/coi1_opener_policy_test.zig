//! Lane coi1: HTML 7.1.3's opener policy decisions - "match opener policy
//! values", the browsing context group switch checks (7.1.3.2) and
//! "enforce a response's opener policy" - as a whole decision table, and the
//! browsing context group state a switch leaves (its cross-origin isolation
//! mode, inherited by every context that joins the group later).

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");

const testing = std.testing;
const opener_policy = html_core.navigation.opener_policy;
const Value = opener_policy.Value;
const BrowsingContext = html_core.BrowsingContext;
const Navigables = html_core.Navigables;

const a_origin = "https://a.test";
const b_origin = "https://b.test";

test "match opener policy values" {
    try testing.expect(opener_policy.match(.unsafe_none, a_origin, .unsafe_none, b_origin));
    try testing.expect(!opener_policy.match(.unsafe_none, a_origin, .same_origin, a_origin));
    try testing.expect(!opener_policy.match(.same_origin, a_origin, .unsafe_none, a_origin));
    try testing.expect(opener_policy.match(.same_origin, a_origin, .same_origin, a_origin));
    try testing.expect(!opener_policy.match(.same_origin, a_origin, .same_origin, b_origin));
    try testing.expect(!opener_policy.match(.same_origin, a_origin, .same_origin_plus_coep, a_origin));
    try testing.expect(opener_policy.match(.same_origin_allow_popups, a_origin, .same_origin_allow_popups, a_origin));
    try testing.expect(opener_policy.match(.noopener_allow_popups, a_origin, .noopener_allow_popups, a_origin));
    // An opaque origin is same origin with nothing serialized.
    try testing.expect(!opener_policy.match(.same_origin, "null", .same_origin, "null"));
}

const all = [_]Value{ .unsafe_none, .same_origin_allow_popups, .same_origin, .same_origin_plus_coep, .noopener_allow_popups };

test "the non-popup check: every pair of values, same and cross origin" {
    for (all) |active| for (all) |response| {
        // Same origin: a switch unless both values are equal (or both
        // unsafe-none, which is the equal case too).
        const same = opener_policy.requiresSwitch(false, a_origin, a_origin, response, active);
        try testing.expectEqual(active != response, same);
        // Cross origin: only two unsafe-none values match.
        const cross = opener_policy.requiresSwitch(false, b_origin, a_origin, response, active);
        try testing.expectEqual(!(active == .unsafe_none and response == .unsafe_none), cross);
    };
}

test "the popup check (from the initial about:blank document): every pair of values" {
    for (all) |active| for (all) |response| {
        for ([_][]const u8{ a_origin, b_origin }) |response_origin| {
            const got = opener_policy.requiresSwitch(true, response_origin, a_origin, response, active);
            const expected = blk: {
                // 1. noopener-allow-popups always switches.
                if (response == .noopener_allow_popups) break :blk true;
                // 2. An opener allowing popups keeps an unsafe-none popup.
                if ((active == .same_origin_allow_popups or active == .noopener_allow_popups) and response == .unsafe_none) break :blk false;
                // 3. Matching values keep it.
                if (active == .unsafe_none and response == .unsafe_none) break :blk false;
                if (active != .unsafe_none and active == response and std.mem.eql(u8, response_origin, a_origin)) break :blk false;
                break :blk true;
            };
            testing.expectEqual(expected, got) catch |err| {
                std.debug.print("active {s} response {s} at {s}\n", .{ @tagName(active), @tagName(response), response_origin });
                return err;
            };
        }
    };
}

test "COOP's popup tests: what an opener with each policy sees of a same-origin and a cross-origin popup" {
    // popup-same-origin-with-same-origin.https.html: an opener with
    // same-origin keeps only a same-origin same-origin popup.
    try testing.expect(opener_policy.requiresSwitch(true, a_origin, a_origin, .unsafe_none, .same_origin));
    try testing.expect(!opener_policy.requiresSwitch(true, a_origin, a_origin, .same_origin, .same_origin));
    try testing.expect(opener_policy.requiresSwitch(true, a_origin, a_origin, .same_origin_allow_popups, .same_origin));
    try testing.expect(opener_policy.requiresSwitch(true, b_origin, a_origin, .same_origin, .same_origin));
    // popup-same-origin-allow-popups-with-cross-origin: an unsafe-none
    // popup is kept, a same-origin one is not.
    try testing.expect(!opener_policy.requiresSwitch(true, b_origin, a_origin, .unsafe_none, .same_origin_allow_popups));
    try testing.expect(opener_policy.requiresSwitch(true, b_origin, a_origin, .same_origin, .same_origin_allow_popups));
    // popup-unsafe-none-with-*: only an unsafe-none popup is kept.
    try testing.expect(!opener_policy.requiresSwitch(true, b_origin, a_origin, .unsafe_none, .unsafe_none));
    try testing.expect(opener_policy.requiresSwitch(true, a_origin, a_origin, .same_origin, .unsafe_none));
}

test "the report-only check" {
    const P = opener_policy.OpenerPolicy;
    // Matching report-only values: no report, whatever the enforced ones say.
    try testing.expect(!opener_policy.reportOnlyRequiresSwitch(false, a_origin, a_origin, P{ .value = .same_origin, .report_only_value = .same_origin }, P{ .report_only_value = .same_origin }));
    // Report-only same-origin to an unsafe-none page: would switch.
    try testing.expect(opener_policy.reportOnlyRequiresSwitch(false, a_origin, a_origin, P{ .report_only_value = .same_origin }, P{}));
    // Step 2: the response's enforced value against the active report-only.
    try testing.expect(opener_policy.reportOnlyRequiresSwitch(false, a_origin, a_origin, P{ .value = .unsafe_none, .report_only_value = .same_origin_allow_popups }, P{ .report_only_value = .same_origin }));
    // Neither side has a report-only value: no switch due to report-only.
    try testing.expect(!opener_policy.reportOnlyRequiresSwitch(false, b_origin, a_origin, P{ .value = .same_origin }, P{}));
}

test "enforce a response's opener policy: flags accumulate across the redirect chain, reports only with others in the group" {
    var reports: opener_policy.Reports = .{};
    const initial: opener_policy.EnforcementResult = .{ .origin = a_origin, .policy = .{ .value = .same_origin } };
    // A cross-origin same-origin response from a same-origin page: switch.
    const first = opener_policy.enforce(false, false, b_origin, .{ .value = .same_origin }, initial, &reports);
    try testing.expect(first.needs_switch);
    try testing.expect(first.current_context_is_navigation_source);
    try testing.expectEqualStrings(b_origin, first.origin);
    try testing.expect(!reports.enforce and !reports.reporting);
    // The next hop matches the first, but the flag stays (step 1).
    const second = opener_policy.enforce(false, false, b_origin, .{ .value = .same_origin }, first, &reports);
    try testing.expect(second.needs_switch);
    // With another context in the group, steps 4.2 and 5.2 report.
    var with_others: opener_policy.Reports = .{};
    const reported = opener_policy.enforce(false, true, b_origin, .{ .value = .same_origin, .report_only_value = .same_origin }, initial, &with_others);
    try testing.expect(reported.needs_switch and reported.would_need_switch_due_to_report_only);
    try testing.expect(with_others.enforce and with_others.reporting);
    // Matching policies: nothing.
    var none: opener_policy.Reports = .{};
    const kept = opener_policy.enforce(false, true, a_origin, .{ .value = .same_origin }, initial, &none);
    try testing.expect(!kept.needs_switch and !kept.would_need_switch_due_to_report_only);
    try testing.expect(!none.enforce and !none.reporting);
}

test "a browsing context group's cross-origin isolation mode: set by a switch, inherited by children and auxiliaries" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const navigables = try scope.table(.navigables, Navigables);
    const top = try BrowsingContext.initTopLevel(testing.allocator, navigables);
    defer top.deinit();
    try testing.expectEqual(.none, top.cross_origin_isolation_mode);
    try testing.expect(!top.groupIsCrossOriginIsolated());

    // A popup it opened before the switch, in its group.
    const earlier_popup = try BrowsingContext.initAuxiliary(testing.allocator, top, true);
    defer earlier_popup.deinit();
    try testing.expect(earlier_popup.opener == top);
    const old_group = top.virtual_group_id;

    try top.setTargetName("named");
    top.switchGroup(.concrete, .empty);
    try testing.expect(top.virtual_group_id != old_group);
    try testing.expectEqual(.concrete, top.cross_origin_isolation_mode);
    try testing.expect(top.groupIsCrossOriginIsolated());
    try testing.expect(top.opener == null);
    try testing.expectEqualStrings("", top.target_name);
    // The popup stays in the old group, and loses its opener: the context
    // it was opened by is gone.
    try testing.expectEqual(old_group, earlier_popup.virtual_group_id);
    try testing.expect(earlier_popup.opener == null);
    try testing.expectEqual(.none, earlier_popup.cross_origin_isolation_mode);

    // A child and a later auxiliary join the new group's mode.
    const child = try BrowsingContext.initChild(testing.allocator, top);
    defer child.deinit();
    try testing.expectEqual(.concrete, child.cross_origin_isolation_mode);
    const grandchild = try BrowsingContext.initChild(testing.allocator, child);
    defer grandchild.deinit();
    const later_popup = try BrowsingContext.initAuxiliary(testing.allocator, grandchild, true);
    defer later_popup.deinit();
    try testing.expectEqual(.concrete, later_popup.cross_origin_isolation_mode);
    try testing.expectEqual(top.virtual_group_id, later_popup.virtual_group_id);

    // A noopener popup starts a new group: none.
    later_popup.startOwnGroup();
    try testing.expectEqual(.none, later_popup.cross_origin_isolation_mode);

    // A switch to a response that is not same-origin-plus-COEP: none.
    top.switchGroup(.none, .empty);
    try testing.expectEqual(.none, top.cross_origin_isolation_mode);
}
