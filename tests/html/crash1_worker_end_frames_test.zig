//! A dedicated worker that ends while its page adds and removes frames reads
//! nothing of the Browser's browsing contexts from the worker's thread (lane
//! crash1).
//!
//! A worker's realm ends on the worker's thread ("run a worker" once its loop
//! exits: WorkerHost.teardownRealm), and ran every unloading document cleanup
//! step there. Lane ifr1 added Fullscreen's ("fully exit fullscreen"), which
//! found the Window through user_activation.windowOfRealm - a walk of the
//! Browser's Navigables, which only the window agent's thread may read. As
//! resource-timing/TAO-match.html added and removed ten frames on the window
//! agent's thread, a referrer-policy worker of an earlier file ended and
//! walked the list: "panic: incorrect alignment" (SIGABRT) once in a
//! 13,683-file production sweep, and in the same sweep a service worker's end
//! faulted on the same walk (crash1_service_worker_end_frames_test).
//!
//! The race is rare; the read is not. A Debug build checks every read of the
//! list against the window agent's thread (dom.browser_state
//! checkWindowAgentThread), so a worker's end that reaches the list fails
//! here on every run - the panic names the read - while the page changes
//! its frames as TAO-match did, or opens and closes popups.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const html = @import("html");

const page_url = "http://crash1.test/page.html";

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the page's loop until `source` is true, changing its frames on
/// every turn.
fn waitWhileChurning(browser: *browser_mod.Browser, source: []const u8) !void {
    for (0..2000) |_| {
        if (try truthy(browser, source)) return;
        const churned = try browser.evaluateScript("churn(); true");
        churned.release();
        _ = try browser.runEventLoopBlocking(2);
    }
    return error.TimedOut;
}

fn round() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    // Frames on the Browser's list, a frame added and one removed at every
    // turn, and a worker that says it runs and is terminated at once - its
    // realm then ends on its own thread while the frames keep changing.
    const started = try browser.evaluateScript(
        \\globalThis.state = 'pending';
        \\for (let i = 0; i < 4; i++) document.body.appendChild(document.createElement('iframe'));
        \\globalThis.churn = () => {
        \\  document.body.appendChild(document.createElement('iframe'));
        \\  document.body.firstElementChild.remove();
        \\};
        \\const worker = new Worker(URL.createObjectURL(new Blob(["postMessage('up')"], { type: 'text/javascript' })));
        \\worker.onmessage = () => { state = 'up'; worker.terminate(); };
        \\worker.onerror = () => { state = 'worker error'; };
        \\true
    );
    started.release();
    try waitWhileChurning(browser, "state !== 'pending'");
    const state = try page.evaluateScriptToString("state", testing.allocator);
    defer testing.allocator.free(state);
    try testing.expectEqualStrings("up", state);

    // The worker's end has run once its owner joined its thread and forgot
    // it: the registry is empty.
    const realm = browser.getRealm() orelse return error.NoRealm;
    const registry = html.WorkerRegistry.existingOf(realm) orelse return error.NoWorkerRegistry;
    for (0..2000) |_| {
        if (registry.count() == 0) break;
        const churned = try browser.evaluateScript("churn(); true");
        churned.release();
        _ = try browser.runEventLoopBlocking(2);
    } else return error.WorkerDidNotEnd;
    // The page's frames are still there, and still change.
    try testing.expect(try truthy(browser, "document.querySelectorAll('iframe').length === 4"));
}

test "a dedicated worker's end, while its page adds and removes frames, reads none of the Browser's browsing contexts" {
    for (0..3) |_| try round();
}

/// Workers start and end one after another while the page opens and closes
/// popups and changes its frames: a closed popup's browsing context is
/// discarded and freed on the window agent's thread too (main's report,
/// 12:34 AM ET: rep2's verify x10 crashed once in the same walk on
/// html/cross-origin-opener-policy/iframe-popup-same-origin-allow-popups-to-same-origin-allow-popups.https.html,
/// a popup closing meanwhile).
fn popupRound() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    const set_up = try browser.evaluateScript(
        \\globalThis.started = 0;
        \\globalThis.ended = 0;
        \\globalThis.failed = 0;
        \\globalThis.popups = [];
        \\for (let i = 0; i < 2; i++) document.body.appendChild(document.createElement('iframe'));
        \\globalThis.churn = () => {
        \\  const popup = window.open('about:blank', '_blank');
        \\  if (popup) popups.push(popup);
        \\  while (popups.length > 2) popups.shift().close();
        \\  document.body.appendChild(document.createElement('iframe'));
        \\  document.body.firstElementChild.remove();
        \\};
        \\globalThis.spawn = () => {
        \\  const worker = new Worker(URL.createObjectURL(new Blob(["postMessage('up')"], { type: 'text/javascript' })));
        \\  started++;
        \\  worker.onmessage = () => { worker.terminate(); ended++; };
        \\  worker.onerror = () => { failed++; };
        \\};
        \\true
    );
    set_up.release();
    // Twelve workers, each started while the last ends.
    for (0..12) |_| {
        const spawned = try browser.evaluateScript("spawn(); true");
        spawned.release();
        try waitWhileChurning(browser, "ended === started || failed > 0");
    }
    try testing.expect(try truthy(browser, "failed === 0 && ended === 12"));
    const realm = browser.getRealm() orelse return error.NoRealm;
    const registry = html.WorkerRegistry.existingOf(realm) orelse return error.NoWorkerRegistry;
    for (0..2000) |_| {
        if (registry.count() == 0) break;
        const churned = try browser.evaluateScript("churn(); true");
        churned.release();
        _ = try browser.runEventLoopBlocking(2);
    } else return error.WorkerDidNotEnd;
    const closed = try browser.evaluateScript("for (const popup of popups) popup.close(); true");
    closed.release();
    _ = try browser.runEventLoopBlocking(20);
}

test "workers that start and end while the page opens and closes popups read none of the Browser's browsing contexts" {
    for (0..2) |_| try popupRound();
}
