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
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const id = popup.id;
    const tab = (try realmTab(popup)).retain();
    // The record, the popup's realm and this test.
    try testing.expect(tab.refs >= 3);

    // The opener lets its WindowProxy go too: a Window script still reaches
    // holds its browsing context (BrowsingContext.window_holds).
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitUntilGone(id);
    // The record ended: the tab closed, and only this test holds it now.
    try testing.expect(tab.closed);
    try testing.expectEqual(@as(u32, 1), tab.refs);
    // The last holder frees it (std.testing.allocator, the Browser's, says
    // whether it was).
    tab.release();
}

test "tabs opened and closed leave no tab scope behind" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    _ = try fixture.hostTab();
    var round: usize = 0;
    while (round < 40) : (round += 1) {
        const id = try fixture.browser.createTab(.{});
        const opened = fixture.tab(id) orelse return error.NoSuchTab;
        // Held by the test: once the tab is gone, nothing else holds it -
        // not its record, not a realm - and the test's release frees it
        // (std.testing.allocator, the Browser's, says whether it did).
        const tab = (try realmTab(opened)).retain();
        defer tab.release();
        try fixture.browser.closeTab(id, .{});
        try fixture.waitUntilGone(id);
        try testing.expect(tab.closed);
        try testing.expectEqual(@as(u32, 1), tab.refs);
    }
}

const SessionShed = @import("html_core").web_storage.TraversableStorageShed;

test "a tab's session storage shed is its scope's, and ends with the tab" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const tab = (try realmTab(popup)).retain();
    defer tab.release();
    const host_tab = try realmTab(host);

    // Storage 4.3: "A traversable navigable holds a storage shed" - its
    // tab's, made with the tab's first session storage.
    try fixture.run(popup, "sessionStorage.setItem('s', 'popup'); true");
    try testing.expect(tab.get(.session_storage, SessionShed) != null);
    // A frame of the popup shares it: its realm is of the same tab.
    try fixture.run(popup, "globalThis.f = document.createElement('iframe'); document.body.appendChild(f); true");
    try fixture.expect(popup, "f.contentWindow.sessionStorage.getItem('s')", "popup");
    // The host's tab holds its own.
    try fixture.run(host, "sessionStorage.setItem('h', 'host'); true");
    try testing.expect(host_tab.get(.session_storage, SessionShed) != null);
    try testing.expect(host_tab.get(.session_storage, SessionShed) != tab.get(.session_storage, SessionShed));
    try fixture.expect(popup, "String(sessionStorage.getItem('h'))", "null");

    // The tab ends: its shed with it.
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitUntilGone(popup.id);
    try testing.expect(tab.closed);
    try testing.expect(tab.get(.session_storage, SessionShed) == null);
}

const JointHistory = @import("html").navigation.joint_history.JointHistory;

test "a tab's session history is its scope's: each tab keeps its own, and it ends with the tab" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const host_tab = try realmTab(host);
    // Two navigations of the host's tab, as a host's UI makes them.
    try fixture.run(host, "globalThis.before = history.length; history.pushState(null, '', '/host.html#one'); history.pushState(null, '', '/host.html#two'); true");
    try fixture.expect(host, "history.length - before", "2");
    const history = host_tab.get(.session_history, JointHistory) orelse return error.NoHistory;
    // The record reads it as its own: one session history.
    try testing.expect(host.joint_history == history);

    // A tab opened beside it has a session history of its own.
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1', 'noopener'); true", "/page.html");
    const tab = (try realmTab(popup)).retain();
    defer tab.release();
    try fixture.expect(popup, "history.length", "1");
    const popup_history = tab.get(.session_history, JointHistory) orelse return error.NoHistory;
    try testing.expect(popup_history != history);
    try fixture.expect(host, "history.length - before", "2");

    // The tab closes: its history goes with it; the host's stays.
    try fixture.browser.closeTraversable(popup.id);
    try fixture.waitUntilGone(tab.id);
    try testing.expect(tab.closed);
    try testing.expect(tab.get(.session_history, JointHistory) == null);
    try testing.expect(host_tab.get(.session_history, JointHistory) == history);
}

const platform = @import("platform");
const html = @import("html");

/// Post the platform's `visibility_changed(tab, visibility)` to the
/// fixture's Browser, as a platform's observer would.
fn postVisibility(fixture: *Fixture, tab: platform.TabId, visibility: platform.Visibility) !void {
    const realm = fixture.browser.getRealm() orelse return error.NoRealm;
    const browser_platform = html.platform_state.of(realm) orelse return error.NoBrowserPlatform;
    const event: platform.PlatformEvent = .{ .kind = .visibility_changed, .tab = tab, .visibility = visibility };
    platform.adapter.postEvent(browser_platform, &event);
}

test "a tab's system visibility is its scope's, and its frames read it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const host_tab = try realmTab(host);
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const tab = try realmTab(popup);
    try testing.expectEqual(TabScope.Visibility.visible, tab.system_visibility);

    // HTML 6.2: the user agent decides a traversable's system visibility -
    // here the platform, for the popup's tab alone.
    try postVisibility(fixture, popup.id, .hidden);
    try fixture.waitFor(popup, "document.visibilityState === 'hidden'");
    try testing.expectEqual(TabScope.Visibility.hidden, tab.system_visibility);
    try testing.expectEqual(TabScope.Visibility.visible, host_tab.system_visibility);
    try fixture.expect(host, "document.visibilityState", "visible");
    // A frame made in the hidden tab starts hidden ("set the initial
    // visibility state" from its traversable's).
    try fixture.run(popup, "globalThis.f = document.createElement('iframe'); document.body.appendChild(f); true");
    try fixture.expect(popup, "f.contentDocument.visibilityState", "hidden");
}

test "a tab's animation frames are its own: closing another tab leaves them running" {
    // The instances design 6.3.2. The frame clock and the animation frame
    // callbacks were the Browser loop's (EventLoop.frames), one set for every
    // tab: a host-opened tab's end (Context.deinit -> rendering.endPage)
    // released every tab's callbacks, and the host page's requestAnimationFrame
    // loop stopped for good.
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    try fixture.run(host, "globalThis.frames_seen = 0; (function tick() { frames_seen++; requestAnimationFrame(tick); })(); true");
    try fixture.waitFor(host, "frames_seen >= 2");

    // A tab the host opens, ticking too; then closed.
    const id = try fixture.browser.createTab(.{});
    const opened = fixture.tab(id) orelse return error.NoSuchTab;
    try fixture.run(opened, "globalThis.frames_seen = 0; (function tick() { frames_seen++; requestAnimationFrame(tick); })(); true");
    try fixture.waitFor(opened, "frames_seen >= 2");
    try fixture.browser.closeTab(id, .{});
    try fixture.waitUntilGone(id);

    // The host's tab keeps its frames.
    try fixture.run(host, "globalThis.after_close = frames_seen; true");
    try fixture.waitFor(host, "frames_seen >= after_close + 3");
}

const interfaces = @import("interfaces");
const dom = @import("dom");

test "one tab's end leaves another tab's pending mutation observers to be notified" {
    // DOM 4.3: the pending mutation observers are the similar-origin window
    // agent's, which every tab of a Browser shares. A host-opened tab's end
    // (Context.deinit) reset the whole agent's (resetAgent): an observer of
    // another tab with a record not yet delivered lost it, never notified.
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const realm = fixture_mod.activeRealm(host) orelse return error.NoRealm;
    try fixture.run(host, "globalThis.seen = []; globalThis.observer = new MutationObserver(records => seen.push(records.length)); observer.observe(document.body, { attributes: true }); true");
    const id = try fixture.browser.createTab(.{});
    _ = fixture.tab(id) orelse return error.NoSuchTab;

    // A mutation in the host's tab from outside script: its record waits for
    // the agent's notify microtask.
    const document: *runtime.Instance = @ptrCast(@alignCast(host.getActiveDocument() orelse return error.NoDocument));
    const body = (try interfaces.Document.get_body(document)) orelse return error.NoBody;
    try interfaces.Element.call_setAttribute(body, runtime.DOMString.initInterned("data-mutated"), .{ .domstring = runtime.DOMString.initInterned("1") });
    const agent = dom.mutation_observer_algorithms.agentOf(realm) orelse return error.NoAgentState;
    try testing.expectEqual(@as(usize, 1), agent.pending_observers.len);

    // The other tab ends: the host tab's observer is still pending...
    try fixture.browser.closeTab(id, .{});
    try testing.expectEqual(@as(usize, 1), agent.pending_observers.len);
    // ...and is notified at the next checkpoint.
    try fixture.waitFor(host, "seen.join() === '1'");
}

test "a realm's platform requests and environment reads name its tab (the platform protocol's recipes step 7)" {
    // The platform names tabs by TabId - the top-level traversable's
    // navigable id; tab 0 is "every tab". A realm's tab gives the mapping
    // the protocol waited for: requests and CSS environment reads made in a
    // tab's realms name it, a frame's its tab's.
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const realm = fixture_mod.activeRealm(host) orelse return error.NoRealm;
    try testing.expectEqual(host.id, html.platform_state.tabOf(realm));
    var parts = (try html.platform_state.requester(realm, false)) orelse return error.NoRequester;
    defer parts.deinit();
    try testing.expectEqual(host.id, parts.requester().tab);
    const popup = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const popup_realm = fixture_mod.activeRealm(popup) orelse return error.NoRealm;
    try testing.expectEqual(popup.id, html.platform_state.tabOf(popup_realm));
}
