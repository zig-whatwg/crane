//! A service worker that ends while a page adds and removes frames reads
//! nothing of the Browser's browsing contexts from the service worker's
//! thread (lane crash1).
//!
//! A service worker's realm ends on its own thread (ServiceThreadHost
//! endRealm -> WorkerHost.teardownRealm) and ran every unloading document
//! cleanup step there, Fullscreen's among them, which walks the Browser's
//! Navigables - the window agent's alone. In lane ifr1's production sweep
//! (2026-11-14) one did, between two files, and faulted ("General protection
//! exception" at user_activation.windowOfRealm, SIGABRT); its dedicated
//! worker twin is tests/html/crash1_worker_end_frames_test.zig.
//!
//! The race is rare; the read is not. A Debug build checks every read of the
//! list against the window agent's thread (dom.browser_state
//! checkWindowAgentThread), so an end that reaches the list fails here on
//! every run. The worker ends as Chromium ends an idle one (the manager's
//! idle timeout, shortened), while the page changes its frames.
//!
//! The script fetch is the test's (no network): the manager's host fetches
//! from a table, and starts and dispatches with the real host (run.zig), as
//! browser_end_test does.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const sw = @import("service_worker");
const registry = sw.registry;

const page_url = "https://crash1-sw.test/page.html";
const worker_script = "self.addEventListener('install', () => {}); self.addEventListener('activate', () => {});";

const test_host: sw.manager.Host = .{
    .fetch = tableFetch,
    .start = sw.run.host.start,
    .dispatch = sw.run.host.dispatch,
    .post_message = sw.run.host.post_message,
    .dispatch_fetch = sw.run.host.dispatch_fetch,
};

fn tableFetch(manager: *sw.Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var outcome: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const allocator = manager.allocator;
    const url = allocator.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = allocator.dupe(u8, worker_script) catch return .{ .failure = .network };
    const content_type = allocator.dupe(u8, "text/javascript") catch return .{ .failure = .network };
    outcome.resources.append(allocator, .{ .url = url, .body = body, .content_type = content_type }) catch return .{ .failure = .network };
    return outcome;
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the page's loop one step, changing its frames.
fn churnTurn(browser: *browser_mod.Browser) !void {
    const churned = try browser.evaluateScript("churn(); true");
    churned.release();
    _ = try browser.runEventLoopBlocking(2);
}

fn round() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const manager = sw.Manager.of(realm) orelse return error.NoManager;
    manager.host = &test_host;
    // A running worker with no event to handle ends this soon after its
    // last one (2.1.1): its activate event.
    manager.idle_timeout_ms = 20;

    const started = try browser.evaluateScript(
        \\globalThis.state = 'none';
        \\for (let i = 0; i < 4; i++) document.body.appendChild(document.createElement('iframe'));
        \\globalThis.churn = () => {
        \\  document.body.appendChild(document.createElement('iframe'));
        \\  document.body.firstElementChild.remove();
        \\};
        \\navigator.serviceWorker.register('/sw.js').then(r => {
        \\  const worker = r.installing || r.waiting || r.active;
        \\  if (worker.state === 'activated') { state = 'activated'; return; }
        \\  worker.addEventListener('statechange', () => { if (worker.state === 'activated') state = 'activated'; });
        \\}, e => { state = 'rejected ' + e.name; });
        \\true
    );
    started.release();
    var turns: usize = 0;
    while (!try truthy(browser, "state !== 'none'")) : (turns += 1) {
        if (turns == 2000) return error.TimedOut;
        try churnTurn(browser);
    }
    const state = try page.evaluateScriptToString("state", testing.allocator);
    defer testing.allocator.free(state);
    try testing.expectEqualStrings("activated", state);

    // The worker ran its activate event; its end has run once the manager
    // forgets it, which it does after the job thread joined its thread
    // (worker_host.endServiceWorkerLink, then Manager.reportEnded).
    turns = 0;
    while (runningWorkers(manager) != 0) : (turns += 1) {
        if (turns == 5000) return error.WorkerDidNotEnd;
        try churnTurn(browser);
    }
    try testing.expect(try truthy(browser, "document.querySelectorAll('iframe').length === 4"));
}

/// The service workers the manager has running - started, and whose end has
/// not come back (Manager.reportEnded).
fn runningWorkers(manager: *sw.Manager) usize {
    std.Io.Threaded.mutexLockUncancelable(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    return manager.running.items.len;
}

test "a service worker's end, while a page adds and removes frames, reads none of the Browser's browsing contexts" {
    for (0..3) |_| try round();
}
