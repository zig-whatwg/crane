//! Lane coi2 batch 2: a ReportingObserver's keep is ended once, by the step
//! that ends its registration.
//!
//! observe() keeps the observer's wrapper while it is registered (Reporting
//! §4, Blink ReportingObserver::HasPendingActivity: `registered_`), and
//! disconnect() ends that keep. Its document's destruction ends it too:
//! Blink keeps no ActiveScriptWrappable of a destroyed ExecutionContext
//! (active_script_wrappable_manager.cc ScriptWrappableIsActive:
//! IsContextDestroyed), Gecko clears the global's mReportingObservers
//! (nsIGlobalObject::UnlinkObjectsInGlobal). Before this batch nothing ended
//! it there: the realm's detach turned the counted keep into an edge from
//! its global, the collector took the observer with the global, and the
//! observer's teardown (Observer.deinit -> disconnect) released a keep that
//! no longer existed - "releasePlatformObject on ReportingObserver ... with
//! no keepPlatformObjectAlive left to end", dozens of times per COEP
//! reporting file in the Debug runner. That log is an error, which fails a
//! unit test (decision D9).
//!
//! Each test runs on a thread of its own (a Browser's agent belongs to the
//! thread that made it) and on std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

fn openPage(html: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

/// Live ReportingObserver slab slots of `browser` - read from the slab, so
/// an observer whose teardown never ran still counts.
fn liveObservers(browser: *browser_mod.Browser) usize {
    var count: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, "ReportingObserver")) count += 1;
        }
    }
    return count;
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

fn removedFrame() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    // The observer is made in, and registered with, a frame's Window; the
    // parent keeps nothing of it.
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(
        \\{
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  const w = frame.contentWindow;
        \\  const observer = new w.ReportingObserver(() => {});
        \\  observer.observe();
        \\  frame.remove();
        \\}
    );
    try testing.expectEqual(@as(usize, 1), liveObservers(browser));
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
    // The observer was collected - its teardown ran - with no unmatched
    // release logged on the way.
    try testing.expectEqual(@as(usize, 0), liveObservers(browser));
}

test "a ReportingObserver registered in a removed frame ends its keep with its document, and its teardown releases nothing" {
    try helpers.onFreshThread(removedFrame);
}

fn pageNavigatedAway(in_place: bool) !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(
        \\globalThis.observers = [];
        \\for (let i = 0; i < 3; i++) { const o = new ReportingObserver(() => {}); o.observe(); o.observe(); observers.push(o); }
    );
    try testing.expectEqual(@as(usize, 3), liveObservers(browser));
    // The page's document goes: the WPT runner's next file (a fresh
    // traversable), or a navigation of the same traversable.
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
    try testing.expectEqual(@as(usize, 0), liveObservers(browser));
}

fn pageReplaced() !void {
    try pageNavigatedAway(false);
}
fn pageNavigatedInPlace() !void {
    try pageNavigatedAway(true);
}

test "ReportingObservers of a page the Browser replaces end their keeps with its document" {
    try helpers.onFreshThread(pageReplaced);
}

test "ReportingObservers of a page navigated in place end their keeps with its document" {
    try helpers.onFreshThread(pageNavigatedInPlace);
}

fn scriptDisconnects() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // observe() twice is one registration and one keep; disconnect() twice
    // ends it once. Dropped afterwards, the observer is collected.
    try page.runScript(
        \\{
        \\  const o = new ReportingObserver(() => {});
        \\  o.observe(); o.observe();
        \\  o.disconnect(); o.disconnect();
        \\}
    );
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveObservers(browser));
    // A registered observer script drops stays: its registration keeps it.
    try page.runScript("{ const o = new ReportingObserver(() => {}); o.observe(); }");
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveObservers(browser));
}

test "observe and disconnect from script take and end exactly one keep" {
    try helpers.onFreshThread(scriptDisconnects);
}
