//! Lane listen1: a PermissionStatus is kept while it has a change listener,
//! and its keep ends at every step that ends that reason.
//!
//! Permissions §6.3.5: "A PermissionStatus object MUST NOT be garbage
//! collected if it has an event listener whose type is change." WebKit keeps
//! it through PermissionStatus::virtualHasPendingActivity, which reads the
//! m_hasChangeEventListener that eventListenersDidChange recomputes after
//! every add and remove, and answers false once its document has no browsing
//! context; Blink through PermissionStatus::AddedEventListener /
//! RemovedEventListener and ActiveScriptWrappable, which keeps nothing of a
//! destroyed ExecutionContext. Before this lane nothing kept it, and a
//! collection between addEventListener and the permission's change took the
//! status and its listener (permissions/permissions-cg.https.html, generation
//! 208: OK -> TIMEOUT).
//!
//! The keep ends when the last change listener goes (removeEventListener,
//! `onchange = null`, the listener's AbortSignal), at the global's end (a
//! global teardown step: a Window the next document reuses keeps it), and
//! never in the status's own teardown, which runs only once the wrapper
//! carrying the count is gone (lesson
//! architecture-a-teardown-never-releases-its-own-keep.md). An unmatched
//! release logs an error, which fails a unit test (decision D9); every test
//! runs on std.testing.allocator and on a thread of its own.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

/// A page at a real origin: its statuses register with the Browser's
/// permission store (an opaque origin has no permission key).
const page_url = "http://127.0.0.1:65533/ls1";

fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

/// Live slab slots of `browser` whose interface is PermissionStatus - read
/// from the slab, so a status whose teardown never ran still counts.
fn liveStatuses(browser: *browser_mod.Browser) usize {
    var count: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, "PermissionStatus")) count += 1;
        }
    }
    return count;
}

/// Run `script`, then the event loop until `globalThis.ready` is true (the
/// queries it made have resolved and their callbacks ran).
fn runUntilReady(browser: *browser_mod.Browser, script: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript("globalThis.ready = false;");
    try page.runScript(script);
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(20);
        const done = try page.evaluateScriptToString("String(globalThis.ready)", testing.allocator);
        defer testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) return;
    }
    return error.QueriesNeverResolved;
}

/// Collect, and let the tasks a collection queues (realm ends, deferred
/// teardowns) run, a few times over.
fn collect(browser: *browser_mod.Browser) !void {
    for (0..4) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

fn changeListenerKeeps() !void {
    const browser = try openPage();
    defer browser.deinit();
    // Two statuses script drops: one with a change listener, one with none.
    try runUntilReady(browser,
        \\Promise.all([
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => { s.addEventListener('change', () => {}); }),
        \\  navigator.permissions.query({name: 'geolocation'}),
        \\]).then(() => { globalThis.ready = true; });
    );
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveStatuses(browser));
}

test "a status with a change listener is kept after script drops it; one with none is collected" {
    try helpers.onFreshThread(changeListenerKeeps);
}

fn handlerKeepsUntilCleared() !void {
    const browser = try openPage();
    defer browser.deinit();
    // onchange set: kept. onchange set then cleared: its listener is gone.
    try runUntilReady(browser,
        \\Promise.all([
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => { s.onchange = () => {}; }),
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => { s.onchange = () => {}; s.onchange = null; }),
        \\]).then(() => { globalThis.ready = true; });
    );
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveStatuses(browser));
}

test "an onchange handler keeps a status, and clearing it ends the keep" {
    try helpers.onFreshThread(handlerKeepsUntilCleared);
}

fn lastListenerRemoved() !void {
    const browser = try openPage();
    defer browser.deinit();
    // Every way the last change listener goes; each status is collected,
    // and no keep is released twice (an unmatched release logs an error).
    try runUntilReady(browser,
        \\Promise.all([
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => {
        \\    const f = () => {};
        \\    s.addEventListener('change', f); s.addEventListener('change', f, true);
        \\    s.removeEventListener('change', f); s.removeEventListener('change', f, true);
        \\    s.removeEventListener('change', f);
        \\  }),
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => {
        \\    const c = new AbortController();
        \\    s.addEventListener('change', () => {}, {signal: c.signal});
        \\    c.abort();
        \\  }),
        \\  navigator.permissions.query({name: 'geolocation'}).then(s => {
        \\    s.addEventListener('other', () => {});
        \\  }),
        \\]).then(() => { globalThis.ready = true; });
    );
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveStatuses(browser));
}

test "the last change listener's removal ends the keep once, however it is removed" {
    try helpers.onFreshThread(lastListenerRemoved);
}

fn statusOfRemovedFrame() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try runUntilReady(browser,
        \\{
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  globalThis.frame = frame;
        \\  frame.contentWindow.navigator.permissions.query({name: 'geolocation'})
        \\    .then(s => { s.onchange = () => {}; globalThis.ready = true; });
        \\}
    );
    try collect(browser);
    // Kept while its frame's global lives.
    try testing.expectEqual(@as(usize, 1), liveStatuses(browser));
    // The frame goes: its global teardown ends the keep, while the realm's
    // wrapper cache still counts it, and the status's own teardown releases
    // nothing.
    try page.runScript("frame.remove(); globalThis.frame = null;");
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveStatuses(browser));
}

test "a kept status of a removed frame ends its keep with its global, and its teardown releases nothing" {
    try helpers.onFreshThread(statusOfRemovedFrame);
}

fn statusesOfPageNavigatedAway(in_place: bool) !void {
    const browser = try openPage();
    defer browser.deinit();
    try runUntilReady(browser,
        \\globalThis.statuses = [];
        \\Promise.all([1, 2, 3].map(() => navigator.permissions.query({name: 'geolocation'})
        \\  .then(s => { s.addEventListener('change', () => {}); statuses.push(s); })))
        \\  .then(() => { globalThis.ready = true; });
    );
    try testing.expectEqual(@as(usize, 3), liveStatuses(browser));
    if (in_place) {
        try browser.navigateInPlace("about:blank");
        _ = try browser.runEventLoopBlocking(50);
    } else {
        try browser.navigate("about:blank", .window);
        const next = browser.current_context orelse return error.NoPage;
        try next.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(20);
    }
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveStatuses(browser));
}

fn pageReplaced() !void {
    try statusesOfPageNavigatedAway(false);
}
fn pageNavigatedInPlace() !void {
    try statusesOfPageNavigatedAway(true);
}

test "kept statuses of a page the Browser replaces end their keeps with its global" {
    try helpers.onFreshThread(pageReplaced);
}

test "kept statuses of a page navigated in place end their keeps with its global" {
    try helpers.onFreshThread(pageNavigatedInPlace);
}

/// A frame whose initial about:blank Window gets a kept status, then a
/// srcdoc document - same origin, so HTML "create and initialize a Document
/// object" step 6 gives it that same Window, which an expando checks.
fn reusedWindow() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try runUntilReady(browser,
        \\{
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  globalThis.frame = frame;
        \\  const w = frame.contentWindow;
        \\  w.reusedMarker = 'initial';
        \\  w.navigator.permissions.query({name: 'geolocation'})
        \\    .then(s => { s.addEventListener('change', () => {}); globalThis.ready = true; });
        \\}
    );
    try page.runScript("frame.srcdoc = '<!doctype html><p id=loaded>srcdoc</p>';");
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(20);
        const done = try page.evaluateScriptToString("String(!!(frame.contentDocument && frame.contentDocument.getElementById('loaded')))", testing.allocator);
        defer testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) break;
    } else return error.SrcdocNeverLoaded;
    const reused = try page.evaluateScriptToString("String(frame.contentWindow.reusedMarker)", testing.allocator);
    defer testing.allocator.free(reused);
    try testing.expectEqualStrings("initial", reused);
    try collect(browser);
    // The about:blank's unload ran its document steps only: the global, and
    // its status's keep, live on.
    try testing.expectEqual(@as(usize, 1), liveStatuses(browser));
    // The frame goes: now the global teardown ends the keep.
    try page.runScript("frame.remove(); globalThis.frame = null;");
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveStatuses(browser));
}

test "a status kept on the initial about:blank stays kept when the next document reuses its Window, and ends with the frame" {
    try helpers.onFreshThread(reusedWindow);
}
