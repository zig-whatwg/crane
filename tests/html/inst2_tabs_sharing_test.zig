//! Two tabs of one Browser share what the Browser holds, and keep what each
//! tab holds (instances-design 6.2; docs/instances.md "The model"; roadmap
//! "instances": "two tabs of one instance share browser-wide state, see
//! each other's storage events and BroadcastChannel messages, and keep their
//! own sessionStorage").
//!
//! A tab is a top-level traversable (docs/instances.md: "every popup is a
//! tab, noopener included"): the host page's, a popup its script opened
//! with an opener (`p`, same browsing context group), and one opened with
//! noopener (a browsing context group of its own - the shape of a tab the
//! host opens: HTML "create a new top-level traversable" with a null
//! opener). All three show http://localhost documents: one origin.
//!
//! Browser-wide (the Browser's scope): localStorage and its storage events,
//! cookies and the Cookie Store's change events, BroadcastChannel, shared
//! workers, Web Locks, blob URLs, service worker registrations, permission
//! state. Per tab (its traversable): sessionStorage, copied into a popup its
//! opener opened and into no other.
const std = @import("std");
const testing = std.testing;
const permissions = @import("permissions");
const fixture_mod = @import("inst2_tabs_fixture.zig");

const Fixture = fixture_mod.Fixture;

/// A popup with an opener, as `p` in the host page.
const open_with_opener = "globalThis.p = window.open('/page.html', 'p1'); true";
/// A noopener popup: window.open() returns null.
const open_noopener = "window.open('/other.html', '_blank', 'noopener'); true";

test "localStorage is the Browser's: every other tab reads a write and hears one storage event, the writer none" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");
    try testing.expectEqual(@as(usize, 3), fixture.tabCount());

    try fixture.run(host, "localStorage.setItem('k', '1'); true");
    try fixture.waitFor(opened, "storageEvents.length === 1");
    try fixture.waitFor(separate, "storageEvents.length === 1");
    // HTML 12.2.1 "broadcast": key, oldValue (null), newValue, url (the
    // writer's document's), storageArea (the receiver's own localStorage).
    try fixture.expect(opened, "storageEvents[0]", "k||1|" ++ fixture_mod.host_url ++ "|local");
    try fixture.expect(separate, "storageEvents[0]", "k||1|" ++ fixture_mod.host_url ++ "|local");
    try fixture.expect(separate, "localStorage.getItem('k')", "1");
    try fixture.expect(opened, "localStorage.getItem('k')", "1");

    // A write from the noopener tab reaches the other two.
    try fixture.run(separate, "localStorage.setItem('k', '2'); true");
    try fixture.waitFor(host, "storageEvents.length === 1");
    try fixture.waitFor(opened, "storageEvents.length === 2");
    try fixture.expect(host, "storageEvents[0]", "k|1|2|" ++ fixture_mod.origin ++ "/other.html|local");
    // The writer hears none of its own.
    try fixture.turn(50);
    try fixture.expect(separate, "storageEvents.length", "1");
}

test "sessionStorage is each tab's: a popup with an opener gets a copy, a noopener one none, and no write reaches another tab" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    try fixture.run(host, "sessionStorage.setItem('s', 'host'); true");

    // HTML "create a new top-level traversable" step 10: legacy-clone the
    // opener's top-level traversable's shed - only when there is an opener.
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");
    try fixture.expect(opened, "sessionStorage.getItem('s')", "host");
    try fixture.expect(separate, "String(sessionStorage.getItem('s'))", "null");

    // A copy, not a share: each tab's writes stay its own.
    try fixture.run(opened, "sessionStorage.setItem('s', 'opened'); true");
    try fixture.run(separate, "sessionStorage.setItem('s', 'separate'); true");
    try fixture.expect(host, "sessionStorage.getItem('s')", "host");
    try fixture.expect(opened, "sessionStorage.getItem('s')", "opened");
    try fixture.expect(separate, "sessionStorage.getItem('s')", "separate");

    // A session storage event goes only to the writer's own traversable's
    // other documents (HTML 12.2.1 "broadcast": the same storage area).
    try fixture.turn(50);
    try fixture.expect(host, "storageEvents.length", "0");
    try fixture.expect(opened, "storageEvents.length", "0");
    try fixture.expect(separate, "storageEvents.length", "0");
}

test "cookies are the Browser's: a cookie one tab sets is every tab's, and the Cookie Store's change event reaches them" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const separate = try fixture.openTab(open_noopener, "/other.html");
    try fixture.run(separate,
        \\globalThis.changes = [];
        \\cookieStore.onchange = e => changes.push(e.changed.map(c => c.name + '=' + c.value).join());
        \\true
    );

    try fixture.run(host, "document.cookie = 'c=1; path=/'; true");
    try fixture.expect(separate, "document.cookie", "c=1");
    try fixture.waitFor(separate, "changes.length === 1");
    try fixture.expect(separate, "changes[0]", "c=1");
}

test "BroadcastChannel delivers a message to every other tab's channel once" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");

    // Each page made `channel` on "c" as it loaded.
    try fixture.run(host, "channel.postMessage('from host'); true");
    try fixture.waitFor(opened, "messages.length === 1");
    try fixture.waitFor(separate, "messages.length === 1");
    try fixture.turn(50);
    try fixture.expect(opened, "messages.join()", "from host");
    try fixture.expect(separate, "messages.join()", "from host");
    // The sending object hears nothing of its own.
    try fixture.expect(host, "messages.length", "0");
}

test "a shared worker is the Browser's: every tab connects to the same one" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");
    const connect =
        \\globalThis.count = 0;
        \\globalThis.worker = new SharedWorker('/counter.js', 'n');
        \\worker.port.onmessage = e => { count = e.data; };
        \\true
    ;
    // One at a time, so the counts are in order.
    try fixture.run(host, connect);
    try fixture.waitFor(host, "count === 1");
    try fixture.run(separate, connect);
    try fixture.waitFor(separate, "count === 2");
    try fixture.run(opened, connect);
    try fixture.waitFor(opened, "count === 3");
}

test "Web Locks are the Browser's: a lock one tab holds is unavailable to another, and closing the holder's tab grants it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");

    try fixture.run(opened,
        \\globalThis.held = false;
        \\navigator.locks.request('x', () => { held = true; return new Promise(() => {}); });
        \\true
    );
    try fixture.waitFor(opened, "held");
    try fixture.run(separate,
        \\globalThis.available = 'pending';
        \\navigator.locks.request('x', { ifAvailable: true }, lock => { available = String(lock); });
        \\globalThis.granted = false;
        \\navigator.locks.request('x', () => { granted = true; });
        \\true
    );
    try fixture.waitFor(separate, "available !== 'pending'");
    try fixture.expect(separate, "available", "null");
    try fixture.turn(50);
    try fixture.expect(separate, "granted", "false");

    // Web Locks: a lock is released when its environment's document goes.
    const opened_id = opened.id;
    // The opener lets its WindowProxy go too: a Window script still reaches
    // holds its browsing context (BrowsingContext.window_holds).
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitFor(separate, "granted");
    try fixture.waitUntilGone(opened_id);
}

test "a blob URL resolves in every tab of its storage key until its document goes" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");

    try fixture.run(opened, "globalThis.url = URL.createObjectURL(new Blob(['blob body'])); true");
    try fixture.run(host, "globalThis.url = p.url; true");
    // The noopener tab has no reference to the popup: the URL travels by
    // localStorage, which every tab shares.
    try fixture.run(opened, "localStorage.setItem('url', url); true");
    const fetch_it =
        \\globalThis.body = 'pending';
        \\fetch(localStorage.getItem('url')).then(r => r.text()).then(t => { body = t; }, () => { body = 'network error'; });
        \\true
    ;
    try fixture.run(separate, fetch_it);
    try fixture.waitFor(separate, "body !== 'pending'");
    try fixture.expect(separate, "body", "blob body");

    // File API 8.3 "Lifetime of blob URLs": the URLs a document's global
    // made are revoked when it is unloaded.
    const opened_id = opened.id;
    // The opener lets its WindowProxy go too: a Window script still reaches
    // holds its browsing context (BrowsingContext.window_holds).
    try fixture.run(host, "p.close(); p = null; true");
    try fixture.waitUntilGone(opened_id);
    try fixture.run(separate, fetch_it);
    try fixture.waitFor(separate, "body !== 'pending'");
    try fixture.expect(separate, "body", "network error");
}

test "a service worker registration is the Browser's: a tab that did not register finds it" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const separate = try fixture.openTab(open_noopener, "/other.html");

    try fixture.run(host,
        \\globalThis.registered = 'pending';
        \\navigator.serviceWorker.register('/sw.js').then(r => { registered = r.scope; }, e => { registered = String(e); });
        \\true
    );
    try fixture.waitFor(host, "registered !== 'pending'");
    try fixture.expect(host, "registered", fixture_mod.origin ++ "/");
    try fixture.run(separate,
        \\globalThis.found = 'pending';
        \\navigator.serviceWorker.getRegistrations().then(rs => { found = rs.map(r => r.scope).join(); });
        \\true
    );
    try fixture.waitFor(separate, "found !== 'pending'");
    try fixture.expect(separate, "found", fixture_mod.origin ++ "/");
}

test "a permission's state is the Browser's: one change reaches every tab's PermissionStatus" {
    const fixture = try Fixture.start(testing.allocator);
    defer fixture.stop();
    const host = try fixture.hostTab();
    const opened = try fixture.openTab(open_with_opener, "/page.html");
    const separate = try fixture.openTab(open_noopener, "/other.html");
    const watch =
        \\globalThis.states = [];
        \\navigator.permissions.query({ name: 'geolocation' }).then(s => { globalThis.status = s; states.push(s.state); s.onchange = () => states.push(s.state); });
        \\true
    ;
    for ([_]*fixture_mod.BrowsingContext{ host, opened, separate }) |tab| {
        try fixture.run(tab, watch);
        try fixture.waitFor(tab, "states.length === 1");
        try fixture.expect(tab, "states[0]", "prompt");
    }

    // Permissions B "set a permission" (WebDriver's automation): the
    // Browser's store, under the tabs' permission key - their top-level
    // origin.
    const store = try fixture.browser.scope.of(permissions.BrowserStore);
    const set = try store.set(fixture_mod.origin, permissions.PermissionDescriptor.simple(.geolocation), .granted);
    set.release();
    for ([_]*fixture_mod.BrowsingContext{ host, opened, separate }) |tab| {
        try fixture.waitFor(tab, "states.length === 2");
        try fixture.expect(tab, "states.join()", "prompt,granted");
    }
}
