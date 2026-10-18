//! HTML "make document unsalvageable", a Document's bfcache blocking details
//! and "build not restored reasons for a top-level traversable and its
//! descendants" (dom.bfcache), and their exposure through
//! PerformanceNavigationTiming.notRestoredReasons (lane bfcache-a).
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const fetch = @import("fetch");
const browser_mod = @import("browser");

const Reason = dom.bfcache.Reason;
const page_url = "http://bfa-nrr.test/page.html";

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn instanceOf(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(html, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

/// A page with a same-origin frame (with an id, no name) holding a frame of
/// its own, and an opaque-origin (sandboxed) frame with neither id nor name.
const page =
    \\<!doctype html><body>
    \\<iframe id=same srcdoc="<iframe srcdoc='<p>grandchild'></iframe>"></iframe>
    \\<iframe sandbox name=other srcdoc="<p>other"></iframe>
    \\</body>
;

fn loadFrames(browser: *browser_mod.Browser) !void {
    try loadPage(browser, page);
    try waitFor(browser,
        \\(() => { const f = document.getElementById("same").contentDocument;
        \\  return f?.readyState === "complete" && f.querySelector("iframe")?.contentDocument?.readyState === "complete"; })()
    );
    try waitFor(browser, "document.getElementsByName('other')[0].contentWindow !== null");
    _ = try browser.runEventLoopBlocking(20);
}

test "make document unsalvageable records each reason once, in order" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><p>page");
    const document = try instanceOf(browser, "document");
    try testing.expectEqual(@as(usize, 0), dom.bfcache.blockingDetails(document).len);
    dom.bfcache.makeUnsalvageable(document, .websocket);
    dom.bfcache.makeUnsalvageable(document, .lock);
    dom.bfcache.makeUnsalvageable(document, .websocket);
    try testing.expectEqualSlices(Reason, &.{ .websocket, .lock }, dom.bfcache.blockingDetails(document));
}

test "aborting a document whose parser is active records parser-aborted" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><iframe id=f></iframe>");
    const frame_document = try instanceOf(browser,
        \\globalThis.bfaFrame = (() => { const d = document.getElementById("f").contentDocument;
        \\  d.open(); d.write("<!doctype html><p>unfinished"); return d; })()
    );
    // window.stop() on the frame aborts it: its parser is still open.
    _ = try browser.evaluateScript("document.getElementById('f').contentWindow.stop()");
    try testing.expect(std.mem.indexOfScalar(Reason, dom.bfcache.blockingDetails(frame_document), .parser_aborted) != null);
}

test "not restored reasons mirror the frame tree: same-origin frames in full, cross-origin ones masked" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadFrames(browser);
    const top = try instanceOf(browser, "document");
    const same = try instanceOf(browser, "globalThis.bfaSame = document.getElementById('same').contentDocument");
    // The sandboxed frame's document is not script's to read from here; its
    // reasons are recorded through its window's environment.
    const other_window = try instanceOf(browser, "globalThis.bfaOther = document.getElementsByName('other')[0].contentWindow");
    dom.bfcache.makeUnsalvageable(same, .fetch);
    dom.bfcache.makeUnsalvageableIn(other_window.ctx, .lock);

    var tree = try dom.bfcache.buildForTopLevelTraversable(top, testing.allocator);
    defer tree.deinit(testing.allocator);
    // The top-level document: no container, its URL, and "masked" because a
    // cross-origin descendant had reasons (step 6).
    try testing.expect(tree.src == null and tree.id == null and tree.name == null);
    try testing.expectEqualStrings(page_url, tree.url.?);
    try testing.expectEqualSlices(Reason, &.{.masked}, tree.reasons.?);
    try testing.expectEqualSlices(Reason, &.{.masked}, dom.bfcache.blockingDetails(top));
    const children = tree.children.?;
    try testing.expectEqual(@as(usize, 2), children.len);
    // The same-origin frame: its container's id, a null name (no
    // attribute), its about:srcdoc URL, its reasons and its own child.
    try testing.expectEqualStrings("same", children[0].id.?);
    try testing.expect(children[0].name == null);
    try testing.expectEqualStrings("", children[0].src.?);
    try testing.expectEqualStrings("about:srcdoc", children[0].url.?);
    try testing.expectEqualSlices(Reason, &.{.fetch}, children[0].reasons.?);
    try testing.expectEqual(@as(usize, 1), children[0].children.?.len);
    try testing.expectEqual(@as(usize, 0), children[0].children.?[0].reasons.?.len);
    try testing.expect(children[0].children.?[0].id == null);
    // The cross-origin frame: masked - no URL, reasons or children - but its
    // container's attributes stay.
    try testing.expectEqualStrings("other", children[1].name.?);
    try testing.expect(children[1].id == null);
    try testing.expect(children[1].url == null and children[1].reasons == null and children[1].children == null);
}

test "notRestoredReasons is null for an ordinary navigation, and the tree it was given otherwise" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadFrames(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;
    try testing.expect(try truthy(browser, "performance.getEntriesByType('navigation').every(e => e.notRestoredReasons === null)"));

    const top = try instanceOf(browser, "document");
    dom.bfcache.makeUnsalvageable(top, .websocket);
    var tree = try dom.bfcache.buildForTopLevelTraversable(top, testing.allocator);
    defer tree.deinit(testing.allocator);

    // The navigation timing entry a back/forward traversal's document gets.
    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    defer timing_info.deinit();
    const report: fetch.internal.TimingReport = .{
        .timing_info = &timing_info,
        .url = page_url,
        .initiator_type = .other,
        .cache_state = "",
        .body_info = .{},
        .response_status = 200,
    };
    try dom.performance_timeline.createNavigationTimingEntry(realm, .{
        .report = &report,
        .redirect_count = 0,
        .navigation_type = .back_forward,
        .not_restored_reasons = &tree,
    });
    try testing.expect(try truthy(browser,
        \\(() => {
        \\  const entry = performance.getEntriesByType("navigation")[0];
        \\  const nrr = entry.notRestoredReasons;
        \\  if (!(nrr instanceof NotRestoredReasons) || nrr !== entry.notRestoredReasons) return false;
        \\  if (nrr.src !== null || nrr.id !== null || nrr.name !== null || nrr.url !== location.href) return false;
        \\  if (!Object.isFrozen(nrr.reasons) || nrr.reasons !== nrr.reasons) return false;
        \\  const reasons = nrr.reasons.map(r => r.reason);
        \\  if (reasons.join() !== "websocket") return false;
        \\  if (!(nrr.reasons[0] instanceof NotRestoredReasonDetails)) return false;
        \\  if (nrr.children.length !== 2 || nrr.children !== nrr.children) return false;
        \\  if (nrr.children[0].id !== "same" || nrr.children[0].name !== null) return false;
        \\  if (nrr.children[1].url !== null || nrr.children[1].reasons !== null) return false;
        \\  const json = JSON.parse(JSON.stringify(nrr));
        \\  return json.reasons[0].reason === "websocket" && json.children[0].id === "same" &&
        \\    json.children[1].name === "other" && json.children[1].reasons === null && json.src === null;
        \\})()
    ));
}
