//! The tab scope (lane tab1; roadmap `instances`, "tab state"): what a tab
//! holds lives in its scope (runtime.TabScope), which its top-level browsing
//! context's record makes and closes, and every Window realm of the tab
//! carries it, as it carries its Browser's scope (docs/instances.md rule 2:
//! "a realm will carry its Browser's scope and its Tab's scope").
//!
//! A tab is one top-level traversable: the host's page, a tab the host opens,
//! a popup a page opens ("every popup is a tab, noopener included"). A frame
//! is of its parent's tab.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const fixture_mod = @import("inst2_tabs_fixture.zig");

const Fixture = fixture_mod.Fixture;
const BrowsingContext = fixture_mod.BrowsingContext;
const TabScope = runtime.TabScope;

/// The tab scope tab `bc`'s active Window realm carries.
fn realmTab(bc: *BrowsingContext) !*TabScope {
    const realm = fixture_mod.activeRealm(bc) orelse return error.NoRealm;
    return TabScope.ofRealm(realm) orelse error.NoTab;
}

test "every Window realm of a tab carries that tab's scope, and only its own" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const host_tab = try realmTab(host);
    try testing.expectEqual(host.id, host_tab.id);
    try testing.expect(host.tabScope() == host_tab);
    try testing.expect(!host_tab.closed);

    // A frame of the tab: of the same tab.
    try fixture.run(host, "globalThis.f = document.createElement('iframe'); document.body.appendChild(f); true");
    try testing.expect(host.children.items.len > 0);
    const frame = host.children.items[host.children.items.len - 1];
    try testing.expect((try realmTab(frame)) == host_tab);

    // A popup a page opens: a tab of its own.
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const popup_tab = try realmTab(popup);
    try testing.expectEqual(popup.id, popup_tab.id);
    try testing.expect(popup_tab != host_tab);

    // A tab the host opens: its own too.
    const id = try fixture.browser.createTab(.{});
    const opened = fixture.tab(id) orelse return error.NoSuchTab;
    const opened_tab = try realmTab(opened);
    try testing.expectEqual(id, opened_tab.id);
    try testing.expect(opened_tab != host_tab and opened_tab != popup_tab);
    try fixture.browser.closeTab(id, .{});
}

test "a tab's scope closes with the tab, and its last holder frees it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const live_before = TabScope.liveCount();
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const id = popup.id;
    const tab = (try realmTab(popup)).retain();
    try testing.expect(TabScope.liveCount() > live_before);

    // The opener lets its WindowProxy go too: a Window script still reaches
    // holds its browsing context (BrowsingContext.window_holds).
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitUntilGone(id);
    // The record ended: the tab closed, and only this test holds it now.
    try testing.expect(tab.closed);
    try testing.expectEqual(@as(u32, 1), tab.refs);
    tab.release();
    try testing.expectEqual(live_before, TabScope.liveCount());
}

test "tabs opened and closed leave no tab scope behind" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    _ = try fixture.hostTab();
    const live_before = TabScope.liveCount();
    var round: usize = 0;
    while (round < 40) : (round += 1) {
        const id = try fixture.browser.createTab(.{});
        const opened = fixture.tab(id) orelse return error.NoSuchTab;
        _ = try realmTab(opened);
        try fixture.browser.closeTab(id, .{});
        try fixture.waitUntilGone(id);
    }
    try testing.expectEqual(live_before, TabScope.liveCount());
}
