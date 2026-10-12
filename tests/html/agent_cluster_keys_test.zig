//! dom.agent_cluster_keys: HTML's requestsOAC ("create and initialize a
//! Document object" steps 7.1-7.3) and "obtain a similar-origin window agent"
//! steps 3-5 with each browsing context group's historical agent cluster key
//! map - kept for as long as one of the group's browsing contexts is live.

const std = @import("std");
const runtime = @import("runtime");
const dom = @import("dom");
const html_core = @import("html_core");

const keys = dom.agent_cluster_keys;
const BrowsingContext = html_core.BrowsingContext;
const Navigables = html_core.Navigables;

test "requestsOAC: only the structured Boolean true, in a secure context" {
    const a = std.testing.allocator;
    try std.testing.expect(keys.requestsOAC(a, "?1", true));
    try std.testing.expect(keys.requestsOAC(a, " ?1 ", true));
    // An item's parameters do not change its bare item.
    try std.testing.expect(keys.requestsOAC(a, "?1;param1;param2=value2", true));
    try std.testing.expect(!keys.requestsOAC(a, null, true));
    try std.testing.expect(!keys.requestsOAC(a, "?0", true));
    try std.testing.expect(!keys.requestsOAC(a, "1", true));
    try std.testing.expect(!keys.requestsOAC(a, "true", true));
    try std.testing.expect(!keys.requestsOAC(a, "?2", true));
    try std.testing.expect(!keys.requestsOAC(a, "?1x", true));
    // Two headers are one list value, which is not an item.
    try std.testing.expect(!keys.requestsOAC(a, "?1, ?1", true));
    // Step 7.3: a non-secure reserved environment ignores it.
    try std.testing.expect(!keys.requestsOAC(a, "?1", false));
}

test "a reserved environment is secure when its top-level creation URL is potentially trustworthy" {
    const a = std.testing.allocator;
    try std.testing.expect(keys.isSecureTopLevelCreationUrl(a, "https://web-platform.test:8443/a.html"));
    try std.testing.expect(keys.isSecureTopLevelCreationUrl(a, "http://localhost:8000/"));
    try std.testing.expect(keys.isSecureTopLevelCreationUrl(a, "http://127.0.0.1:8000/"));
    try std.testing.expect(keys.isSecureTopLevelCreationUrl(a, "about:blank"));
    try std.testing.expect(!keys.isSecureTopLevelCreationUrl(a, "http://web-platform.test:8000/a.html"));
    try std.testing.expect(!keys.isSecureTopLevelCreationUrl(a, "not a url"));
}

test "obtain: an origin's first document decides its keying for the group" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    // The Browser's list, which the scope keeps and ends.
    const navigables = try scope.table(.navigables, Navigables);
    // Two live groups: two top-level browsing contexts of their own.
    const tab1 = try BrowsingContext.initTopLevel(std.testing.allocator, navigables);
    defer tab1.deinit();
    const tab2 = try BrowsingContext.initTopLevel(std.testing.allocator, navigables);
    defer tab2.deinit();
    const g1 = tab1.virtual_group_id;
    const g2 = tab2.virtual_group_id;
    const parent = "https://web-platform.test:8443";
    const sub = "https://www.web-platform.test:8443";

    // No document of `sub` yet: site-keyed.
    try std.testing.expect(!keys.isOriginKeyed(&scope, g1, sub, false));
    // The parent sends no header: its origin is site-keyed from now on.
    try std.testing.expect(!keys.obtain(&scope, g1, parent, false, false));
    // A later document of the parent's origin asking for origin-keying does
    // not get it (step 4).
    try std.testing.expect(!keys.obtain(&scope, g1, parent, true, false));
    try std.testing.expect(!keys.isOriginKeyed(&scope, g1, parent, false));
    // The subdomain's first document asks: origin-keyed (step 5.1), and so is
    // a later one that does not ask.
    try std.testing.expect(keys.obtain(&scope, g1, sub, true, false));
    try std.testing.expect(keys.obtain(&scope, g1, sub, false, false));
    try std.testing.expect(keys.isOriginKeyed(&scope, g1, sub, false));
    // Another group has a map of its own: its first document decides afresh.
    try std.testing.expect(!keys.isOriginKeyed(&scope, g2, sub, false));
    try std.testing.expect(keys.obtain(&scope, g2, parent, true, false));
    try std.testing.expect(keys.isOriginKeyed(&scope, g2, parent, false));
    try std.testing.expect(!keys.isOriginKeyed(&scope, g1, parent, false));
}

test "obtain: an opaque origin and a cross-origin isolated group are origin-keyed, and record nothing" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    // The Browser's list, which the scope keeps and ends.
    const navigables = try scope.table(.navigables, Navigables);
    const tab = try BrowsingContext.initTopLevel(std.testing.allocator, navigables);
    defer tab.deinit();
    const g = tab.virtual_group_id;
    try std.testing.expect(keys.obtain(&scope, g, "null", false, false));
    try std.testing.expect(keys.isOriginKeyed(&scope, g, "null", false));
    try std.testing.expect(keys.obtain(&scope, g, "https://a.test", false, true));
    try std.testing.expect(keys.isOriginKeyed(&scope, g, "https://a.test", true));
    // Step 3 decided without the map: the origin is still unrecorded, so a
    // later document outside isolation decides for itself.
    try std.testing.expect(!keys.isOriginKeyed(&scope, g, "https://a.test", false));
    try std.testing.expect(keys.obtain(&scope, g, "https://a.test", true, false));
    // No Browser: the request alone, recorded nowhere.
    try std.testing.expect(keys.obtain(null, g, "https://b.test", true, false));
    try std.testing.expect(!keys.isOriginKeyed(null, g, "https://b.test", false));
}

test "a group's map goes once none of its browsing contexts is live" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    // The Browser's list, which the scope keeps and ends.
    const navigables = try scope.table(.navigables, Navigables);
    const tab1 = try BrowsingContext.initTopLevel(std.testing.allocator, navigables);
    const g1 = tab1.virtual_group_id;
    // A frame of the group, and a popup its page opened, keep it alive after
    // the tab's own context goes.
    const frame = try BrowsingContext.initChild(std.testing.allocator, tab1);
    const popup = try BrowsingContext.initAuxiliary(std.testing.allocator, tab1, true);
    const tab2 = try BrowsingContext.initTopLevel(std.testing.allocator, navigables);
    defer tab2.deinit();
    const g2 = tab2.virtual_group_id;
    const origin = "https://web-platform.test:8443";

    try std.testing.expect(keys.obtain(&scope, g1, origin, true, false));
    tab1.deinit();
    frame.deinit();
    // Recording in another group forgets only groups that have ended.
    _ = keys.obtain(&scope, g2, "https://other.test", false, false);
    try std.testing.expect(keys.isOriginKeyed(&scope, g1, origin, false));
    popup.deinit();
    _ = keys.obtain(&scope, g2, "https://third.test", false, false);
    try std.testing.expect(!keys.isOriginKeyed(&scope, g1, origin, false));
    try std.testing.expect(!keys.isOriginKeyed(&scope, g2, "https://other.test", false));
    const historical = scope.existing(keys.HistoricalKeys) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u32, 1), historical.groups.count());
}
