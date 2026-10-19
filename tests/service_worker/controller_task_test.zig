//! ServiceWorkerContainer.controller changes in the task that fires
//! controllerchange, never before it: a task the client's loop runs between
//! the registry's change (clients.claim() on the job thread) and the
//! controllerchange task still sees the old controller. Chromium
//! (ServiceWorkerContainer::SetController) and Gecko
//! (ServiceWorkerContainer::ControllerChanged) set the container's
//! controller and fire controllerchange in one step.
//!
//! The order is made deterministic: the page's getRegistration() posts its
//! resolution task before the page asks its service worker to claim it, and
//! the test waits - without running the page's loop - until the registry has
//! the page controlled, so the controllerchange task is queued behind that
//! resolution when the loop runs again.
//!
//! The script fetch is the test's (no network): the manager's host fetches
//! from a table, and starts and dispatches with the real host (run.zig).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const sw = @import("service_worker");
const registry = sw.registry;

const page_url = "https://sw-controller.test/page.html";
const claim_on_message = "self.addEventListener('message', e => e.waitUntil(clients.claim()));";

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
    const body = allocator.dupe(u8, claim_on_message) catch return .{ .failure = .network };
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

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
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

fn sleepMs(ms: u64) void {
    std.Io.Threaded.global_single_threaded.io().sleep(.fromNanoseconds(@intCast(ms * std.time.ns_per_ms)), .awake) catch {};
}

test "a task queued before controllerchange's still sees the old controller, though the registry has changed it" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
    const realm = browser.getRealm() orelse return error.NoRealm;
    const manager = sw.Manager.of(realm) orelse return error.NoManager;
    manager.host = &test_host;

    // A registration whose active worker claims the page when asked; the
    // page, registered after it loaded, is not controlled.
    try run(browser,
        \\globalThis.state = { changes: 0, seen: 'not run' };
        \\navigator.serviceWorker.register('/sw.js', { scope: '/' }).then(r => { globalThis.state.reg = r; });
    );
    try waitFor(browser, "globalThis.state.reg && globalThis.state.reg.active && globalThis.state.reg.active.state === 'activated'");
    try testing.expect(try truthy(browser, "navigator.serviceWorker.controller === null"));
    const environment = sw.realm.environmentOf(realm, false) orelse return error.NoEnvironment;
    const environment_id = environment.id;

    // T1: getRegistration()'s resolution, queued now. Then the claim.
    try run(browser,
        \\navigator.serviceWorker.addEventListener('controllerchange', () => {
        \\  globalThis.state.changes++;
        \\  globalThis.state.atChange = navigator.serviceWorker.controller;
        \\});
        \\navigator.serviceWorker.getRegistration().then(() => {
        \\  globalThis.state.seen = navigator.serviceWorker.controller;
        \\});
        \\globalThis.state.reg.active.postMessage('claim');
    );
    // The registry has the page controlled: controllerchange's task is
    // queued behind T1 (the page's loop has not run since).
    var waited: usize = 0;
    while (true) : (waited += 1) {
        if (waited > 10_000) return error.NeverClaimed;
        var info = (try manager.controllerOf(testing.allocator, environment_id)) orelse {
            sleepMs(1);
            continue;
        };
        info.deinit(testing.allocator);
        break;
    }

    try waitFor(browser, "globalThis.state.changes === 1");
    // T1's reaction ran before controllerchange: the old controller.
    if (!try truthy(browser, "globalThis.state.seen === null")) {
        const seen = try context.evaluateScriptToString("String(globalThis.state.seen)", testing.allocator);
        defer testing.allocator.free(seen);
        std.debug.print("the task before controllerchange saw controller = {s}\n", .{seen});
        return error.ControllerChangedBeforeItsEvent;
    }
    // The event's listener sees the new one, as does script after it.
    try testing.expect(try truthy(browser, "globalThis.state.atChange === globalThis.state.reg.active"));
    try testing.expect(try truthy(browser, "navigator.serviceWorker.controller === globalThis.state.reg.active"));
}
