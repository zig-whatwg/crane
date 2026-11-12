//! A host's young-generation limit reaches a service worker's agent too
//! (tests/html/v8up_worker_young_generation_test.zig has the window agent
//! and the dedicated and shared workers): Browser.Config.
//! young_generation_limit -> the Browser's WorkerRegistry -> the
//! engine.AgentOptions.young_generation_limit of the agent the service
//! worker's thread makes (worker_host.zig). A Browser that sets nothing gives
//! it the protocol's one default.
//!
//! The worker's install event never settles, so its agent stays alive while
//! the test reads engine.youngGenerationLimitOf under its link's agent lock.
//! The script fetch is the test's (no network), as in browser_end_test.zig.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const html = @import("html");
const sw = @import("service_worker");
const registry = sw.registry;

const mb = 1024 * 1024;
const page_url = "https://sw-young-generation.test/page.html";
const stuck_script = "self.addEventListener('install', e => e.waitUntil(new Promise(() => {})));";

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

/// What each live worker agent of `browser` got, read through its
/// WorkerRegistry's links.
fn workerLimits(browser: *browser_mod.Browser, limits: *[8]?usize) usize {
    const workers = browser.scope.existing(html.WorkerRegistry) orelse return 0;
    std.Io.Threaded.mutexLockUncancelable(&workers.mutex);
    defer std.Io.Threaded.mutexUnlock(&workers.mutex);
    var count: usize = 0;
    for (workers.links.items) |link| {
        std.Io.Threaded.mutexLockUncancelable(&link.agent_lock);
        defer std.Io.Threaded.mutexUnlock(&link.agent_lock);
        const agent = link.agent orelse continue;
        if (count == limits.len) break;
        limits[count] = engine.youngGenerationLimitOf(agent);
        count += 1;
    }
    return count;
}

fn check(browser: *browser_mod.Browser) !void {
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
    // The worker runs its install event, which never settles: its agent lives.
    try waitFor(browser, "globalThis.state === 'installing'");

    const window_limit = engine.youngGenerationLimitOf(browser.agent orelse return error.NoAgent);
    var limits: [8]?usize = undefined;
    const count = workerLimits(browser, &limits);
    if (count != 1) std.debug.print("{d} worker agent(s) live, expected the service worker's\n", .{count});
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expectEqual(window_limit, limits[0]);
}

test "a Browser configured with a 24 MB young generation: its service worker's agent gets 24 MB" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .young_generation_limit = 24 * mb });
    defer browser.deinit();
    const honoured = comptime engine.capabilities.young_generation_limit != .unsupported;
    try testing.expectEqual(@as(?usize, if (honoured) 24 * mb else null), engine.youngGenerationLimitOf(browser.agent orelse return error.NoAgent));
    try check(browser);
}

test "a Browser with no young-generation limit set: its service worker's agent gets the protocol's default" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    if (engine.default_young_generation_limit == null) try testing.expectEqual(@as(?usize, null), engine.youngGenerationLimitOf(browser.agent orelse return error.NoAgent));
    try check(browser);
}
