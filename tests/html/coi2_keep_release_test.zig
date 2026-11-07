//! Lane coi2 batch 2: a ReportingObserver's and a BroadcastChannel's keeps
//! are ended once, by the step that ends their registration.
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
//! unit test (decision D9). A BroadcastChannel's constructor keep had the
//! same shape (its teardown released it when the channel was not closed);
//! Blink ends it at ContextDestroyed.
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

/// Live slab slots of `browser` whose interface is `name` - read from the
/// slab, so an object whose teardown never ran still counts.
fn liveOf(browser: *browser_mod.Browser, name: []const u8) usize {
    var count: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, name)) count += 1;
        }
    }
    return count;
}

fn liveObservers(browser: *browser_mod.Browser) usize {
    return liveOf(browser, "ReportingObserver");
}

fn liveChannels(browser: *browser_mod.Browser) usize {
    return liveOf(browser, "BroadcastChannel");
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

fn channelInRemovedFrame() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    // An open channel made in a frame's Window, which the parent keeps
    // nothing of.
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(
        \\{
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  const channel = new frame.contentWindow.BroadcastChannel('coi2');
        \\  channel.onmessage = () => {};
        \\  frame.remove();
        \\}
    );
    try testing.expectEqual(@as(usize, 1), liveChannels(browser));
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveChannels(browser));
}

test "an open BroadcastChannel of a removed frame ends its keep with its document, and its teardown releases nothing" {
    try helpers.onFreshThread(channelInRemovedFrame);
}

fn channelsOfPageNavigatedInPlace() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // Open, closed once, closed twice: each keep ends once.
    try page.runScript(
        \\globalThis.channels = [new BroadcastChannel('a'), new BroadcastChannel('b'), new BroadcastChannel('c')];
        \\channels[1].close();
        \\channels[2].close(); channels[2].close();
    );
    try testing.expectEqual(@as(usize, 3), liveChannels(browser));
    try browser.navigateInPlace("about:blank");
    _ = try browser.runEventLoopBlocking(50);
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveChannels(browser));
}

test "BroadcastChannels of a page navigated in place end their keeps once, open or closed" {
    try helpers.onFreshThread(channelsOfPageNavigatedInPlace);
}

fn closedChannelIsCollected() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // close() ends the keep: dropped, the channel is collected; an open one
    // script drops stays.
    try page.runScript("{ const c = new BroadcastChannel('x'); c.close(); c.close(); } { new BroadcastChannel('y'); }");
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveChannels(browser));
}

test "close() ends a BroadcastChannel's keep once, and an open channel stays kept" {
    try helpers.onFreshThread(closedChannelIsCollected);
}

// ---------------------------------------------------------------------------
// Lane coi2 batch 3: a Window the next document reuses
// ---------------------------------------------------------------------------
//
// An iframe's initial about:blank and the same-origin document that replaces
// it share one Window (HTML "create and initialize a Document object" step 6:
// "both ... will share the same Window object"). The about:blank's unload runs
// its document cleanup steps, but the global's own teardown - its
// ReportingObservers' registrations (Reporting §4 keeps them on the global),
// its BroadcastChannels' keeps - waits for the global's end: Blink ends both
// only at ContextDestroyed, which a reused LocalDOMWindow (DocumentLoader
// ShouldReuseDOMWindow) never gets. It ran at the about:blank's unload, so an
// observer or channel of that Window was not kept and a collection took it
// (html/cross-origin-embedder-policy/reporting-navigation.https.html lost its
// reports at random).

/// A page at an http origin with one iframe (window.frame), and `before`
/// run in the frame's initial about:blank Window (`w`); then the frame
/// navigates to a srcdoc document - its origin is the page's, so the Window
/// is reused, which the script checks with an expando - and `after` runs in
/// that same Window. Returns the Browser, with the event loop run to the
/// srcdoc document's load.
fn reusedFrame(before: []const u8, after: []const u8) !*browser_mod.Browser {
    return reusedFrameBy(before, after, "frame.srcdoc = '<!doctype html><p id=loaded>srcdoc</p>';");
}

/// `reusedFrame`, with `navigate` the script that navigates the frame (its
/// new document has an element with id "loaded").
fn reusedFrameBy(before: []const u8, after: []const u8, navigate: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/coi2b3" });
    _ = try browser.runEventLoopBlocking(20);
    const setup = try std.fmt.allocPrint(testing.allocator,
        \\{{
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  globalThis.frame = frame;
        \\  const w = frame.contentWindow;
        \\  w.reusedMarker = 'initial';
        \\  {s}
        \\  {s}
        \\}}
    , .{ before, navigate });
    defer testing.allocator.free(setup);
    try page.runScript(setup);
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
    const rest = try std.fmt.allocPrint(testing.allocator, "{{ const w = frame.contentWindow; {s} }}", .{after});
    defer testing.allocator.free(rest);
    try page.runScript(rest);
    return browser;
}

fn observerOfReusedWindow() !void {
    const browser = try reusedFrame("", "new w.ReportingObserver(() => {}).observe();");
    defer browser.deinit();
    try collect(browser);
    // Its registration keeps it: the Window it observes is live.
    try testing.expectEqual(@as(usize, 1), liveObservers(browser));
}

test "a ReportingObserver registered in a Window the next document reused stays kept" {
    try helpers.onFreshThread(observerOfReusedWindow);
}

fn observerBeforeTheReusingNavigation() !void {
    const browser = try reusedFrame("new w.ReportingObserver(() => {}).observe();", "");
    defer browser.deinit();
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveObservers(browser));
}

test "a ReportingObserver registered on the initial about:blank stays kept when the next document reuses its Window" {
    try helpers.onFreshThread(observerBeforeTheReusingNavigation);
}

fn channelBeforeTheReusingNavigation() !void {
    const browser = try reusedFrame("{ const c = new w.BroadcastChannel('coi2b3'); c.onmessage = () => {}; }", "");
    defer browser.deinit();
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveChannels(browser));
}

test "a BroadcastChannel made on the initial about:blank stays kept when the next document reuses its Window" {
    try helpers.onFreshThread(channelBeforeTheReusingNavigation);
}

fn reusedWindowRemoved() !void {
    const browser = try reusedFrame("new w.ReportingObserver(() => {}).observe(); { const c = new w.BroadcastChannel('coi2b3'); c.onmessage = () => {}; }", "new w.ReportingObserver(() => {}).observe();");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // The frame goes: its global is discarded, and the teardown it waited for
    // runs - nothing of the Window is kept any longer.
    try page.runScript("frame.remove(); globalThis.frame = null;");
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
    try testing.expectEqual(@as(usize, 0), liveObservers(browser));
    try testing.expectEqual(@as(usize, 0), liveChannels(browser));
}

test "the reused Window's observers and channels end their keeps once its frame is removed" {
    try helpers.onFreshThread(reusedWindowRemoved);
}

fn observerBeforeJavascriptUrl() !void {
    const browser = try reusedFrameBy("new w.ReportingObserver(() => {}).observe();", "", "frame.src = \"javascript:'<!doctype html><p id=loaded>javascript</p>'\";");
    defer browser.deinit();
    try collect(browser);
    try testing.expectEqual(@as(usize, 1), liveObservers(browser));
}

test "a ReportingObserver registered on the initial about:blank stays kept when a javascript: URL's document reuses its Window" {
    try helpers.onFreshThread(observerBeforeJavascriptUrl);
}
