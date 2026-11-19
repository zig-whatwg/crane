//! A tab's session storage ends with the tab (roadmap "instances": "Tab
//! state (session history, sessionStorage per top-level traversable, ...)
//! belongs to the tab"; instances-design 4.7, a tab's close: "the
//! traversable storage shed goes with it - session storage does not outlive
//! the tab").
//!
//! Storage 4.3: "A traversable navigable holds a storage shed ... [which]
//! holds all session storage data"; HTML "destroy a top-level traversable"
//! step 5 removes the traversable from the user agent's top-level
//! traversable set, and what it holds goes with it. Firefox keeps a tab's
//! session storage on its top-level BrowsingContext (SessionStorageManager on
//! Top()), which ends with it.
//!
//! Crane kept every traversable's shed until its Browser ended: one per
//! closed popup, and in a WPT runner process one per test file (each file is
//! a fresh traversable, Browser.navigate).
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const fixture_mod = @import("inst2_tabs_fixture.zig");

const Fixture = fixture_mod.Fixture;

/// Whether the Browser still holds a session storage shed for tab `id`.
fn hasShed(fixture: *Fixture, id: u64) bool {
    const navigables = dom.browser_state.existingNavigablesIn(fixture.browser.scope) orelse return false;
    return navigables.traversable_storage.contains(id);
}

test "a popup tab's session storage ends when the tab is closed" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const id = opened.id;
    try fixture.run(opened, "sessionStorage.setItem('s', 'x'.repeat(1000)); true");
    try testing.expect(hasShed(fixture, id));

    // The opener lets its WindowProxy go too: a Window script still reaches
    // holds its browsing context (BrowsingContext.window_holds).
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitUntilGone(id);
    try testing.expect(!hasShed(fixture, id));
    // The host's tab keeps its own.
    try fixture.run(host, "sessionStorage.setItem('h', '1'); true");
    try testing.expect(hasShed(fixture, host.id));
}

test "a noopener tab the host closes takes its session storage with it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const separate = try fixture.openTab("window.open('/other.html', '_blank', 'noopener'); true", "/other.html");
    const id = separate.id;
    try fixture.run(separate, "sessionStorage.setItem('s', '1'); true");
    try testing.expect(hasShed(fixture, id));

    // The host's UI closes it (HTML "close a top-level traversable").
    try fixture.browser.closeTraversable(id);
    try fixture.waitUntilGone(id);
    try testing.expect(!hasShed(fixture, id));
}

test "the host page's traversable takes its session storage with it when a fresh one replaces it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const first = try fixture.hostTab();
    const first_id = first.id;
    try fixture.run(first, "sessionStorage.setItem('s', 'first'); true");
    try testing.expect(hasShed(fixture, first_id));

    // Browser.navigate: a FRESH top-level traversable, the one before it
    // closed - what the WPT runner does for each file.
    try fixture.showHostPage(fixture_mod.origin ++ "/second.html");
    const second = try fixture.hostTab();
    try testing.expect(second.id != first_id);
    try fixture.waitUntilGone(first_id);
    try testing.expect(!hasShed(fixture, first_id));
    // A new traversable: none of the old one's session storage.
    try fixture.expect(second, "String(sessionStorage.getItem('s'))", "null");
}

test "an opener holding a closed popup's sessionStorage reads it safely after the popup's end" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab("globalThis.p = window.open('/page.html', 'p1'); true", "/page.html");
    const id = opened.id;
    // The opener keeps the popup's Storage object and lets the popup itself
    // go: closed, its WindowProxy dropped.
    try fixture.run(host, "globalThis.kept = p.sessionStorage; kept.setItem('k', 'v'); p.close(); p = null; true");
    // The popup closes and its realm ends; the Storage object outlives them,
    // whatever its Window and its browsing context's record do meanwhile.
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        try fixture.turn(10);
        if (turns % 20 == 19) try fixture.collect();
    }
    // Every member of the kept Storage answers without touching freed
    // memory: its shed stays while anything of its traversable reads it.
    try fixture.run(host,
        \\globalThis.reads = [];
        \\for (const read of [() => kept.getItem('k'), () => kept.length, () => kept.key(0), () => { kept.setItem('k', 'w'); return 'set'; }, () => { kept.clear(); return 'cleared'; }]) {
        \\  try { reads.push('value:' + String(read())); } catch (e) { reads.push('threw:' + e.name); }
        \\}
        \\true
    );
    const answer = try fixture_mod.evaluateIn(fixture_mod.activeRealm(host).?, "reads.join()");
    defer testing.allocator.free(answer);
    std.debug.print("a closed popup's Storage, read by its opener: {s}; its browsing context {s}\n", .{ answer, if (dom.browser_state.existingNavigablesIn(fixture.browser.scope).?.byId(id) == null) "freed" else "held" });

    // Once the opener lets it go too, the traversable's record ends, and its
    // shed with it.
    try fixture.run(host, "kept = null; true");
    try fixture.waitUntilGone(id);
    try testing.expect(!hasShed(fixture, id));
}
