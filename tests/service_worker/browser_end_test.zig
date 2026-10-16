//! A Browser that ends with a service worker stuck installing - its install
//! event's waitUntil() promise never settles, so its register job holds its
//! scope's queue - still ends cleanly: its WorkerRegistry terminates and
//! joins the service worker's thread and the manager's job thread, and the
//! manager frees what is left (docs/instances.md's teardown order). The WPT
//! runner restarts its Browser after every file that times out, so this
//! teardown runs whenever a file leaves a worker stuck.
//!
//! The script fetch is the test's (no network): the manager's host fetches
//! from a table, and starts and dispatches with the real host (run.zig).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const sw = @import("service_worker");
const registry = sw.registry;

const page_url = "https://sw-end.test/page.html";
const stuck_script = "self.addEventListener('install', e => e.waitUntil(new Promise(() => {})));";

const test_host: sw.manager.Host = .{
    .fetch = tableFetch,
    .start = sw.run.host.start,
    .dispatch = sw.run.host.dispatch,
};

fn tableFetch(manager: *sw.Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var outcome: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const allocator = manager.allocator;
    const url = allocator.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = allocator.dupe(u8, stuck_script) catch return .{ .failure = .network };
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

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

test "a Browser ends while a service worker's install never settles: its threads are joined, nothing leaks" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
    const realm = browser.getRealm() orelse return error.NoRealm;
    const manager = sw.Manager.of(realm) orelse return error.NoManager;
    manager.host = &test_host;

    const started = try browser.evaluateScript(
        \\globalThis.state = "none";
        \\navigator.serviceWorker.register("/sw.js").then(r => {
        \\  globalThis.state = r.installing ? r.installing.state : "no installing worker";
        \\}, e => { globalThis.state = "rejected " + e.name; });
    );
    started.release();
    // The worker runs its install event, which never settles.
    waitFor(browser, "globalThis.state === 'installing'") catch |err| {
        const state = try context.evaluateScriptToString("String(globalThis.state)", testing.allocator);
        defer testing.allocator.free(state);
        std.debug.print("state: {s}\n", .{state});
        return err;
    };
    // A second job for the scope waits behind the stuck one.
    const queued = try browser.evaluateScript("navigator.serviceWorker.register('/sw.js', { scope: '/', updateViaCache: 'none' }); true");
    queued.release();
    _ = try browser.runEventLoopBlocking(50);
    // browser.deinit (deferred): every thread joined, every record freed -
    // testing.allocator reports what is not.
}
