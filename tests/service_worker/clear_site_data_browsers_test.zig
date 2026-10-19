//! Clear-Site-Data's "storage" clears one Browser's service worker
//! registrations, never another's - even for the same origin - and it runs on
//! the fetching thread, which need not be the thread of the clients it
//! changes.
//!
//! Two Browsers on two threads each register a service worker for the same
//! origin, whose activate event claims the page. Then a third thread - the
//! "fetching thread" - runs Browser A's Clear-Site-Data handler (what
//! HTTP-network fetch calls through the request's network context) while
//! Browser B registers a second scope of its own. A's page hears
//! controllerchange on its own thread and loses its controller, its worker
//! goes redundant and A has no registrations left; B's two registrations and
//! its controller are untouched.
//!
//! The script fetch is the test's (no network): each manager's host fetches
//! from a table, and starts and dispatches with the real host (run.zig).
//! Each Browser allocates from a DebugAllocator of its own (a shared
//! std.testing.allocator makes two Browsers take turns - AGENTS.md).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const fetch = @import("fetch");
const sw = @import("service_worker");
const registry = sw.registry;

const origin = "https://csd.test";
const page_url = origin ++ "/page.html";
const claim_script = "self.addEventListener('activate', e => e.waitUntil(clients.claim()));";

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
    const body = allocator.dupe(u8, claim_script) catch return .{ .failure = .network };
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
    while (turns < 1500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    const context = browser.current_context orelse return error.TimedOut;
    const state = context.evaluateScriptToString("JSON.stringify(globalThis.state ?? null)", testing.allocator) catch return error.TimedOut;
    defer testing.allocator.free(state);
    std.debug.print("timed out waiting for: {s} (state {s})\n", .{ source, state });
    return error.TimedOut;
}

/// Turn the Browser's event loop until `flag` is set. The bound matches the
/// fetching thread's 60 s wait for both sides: the other side may still be
/// starting its service worker when this one is ready, and under a full
/// `zig build test` load that took more than the old 10 s (two gate failures,
/// 2026-10-19).
fn pumpUntil(browser: *browser_mod.Browser, flag: *const std.atomic.Value(bool)) !void {
    var turns: usize = 0;
    while (!flag.load(.acquire)) : (turns += 1) {
        if (turns > 12_000) return error.TheOtherSideNeverCame;
        _ = try browser.runEventLoopBlocking(5);
    }
}

/// A page of `origin`, controlled by a service worker its activate event
/// claimed it for.
fn controlledPage(browser: *browser_mod.Browser) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
    const realm = browser.getRealm() orelse return error.NoRealm;
    const manager = sw.Manager.of(realm) orelse return error.NoManager;
    manager.host = &test_host;
    try run(browser,
        \\globalThis.state = { changes: 0 };
        \\navigator.serviceWorker.addEventListener('controllerchange', () => { globalThis.state.changes++; });
        \\navigator.serviceWorker.register('/sw.js', { scope: '/' });
    );
    try waitFor(browser, "navigator.serviceWorker.controller !== null && navigator.serviceWorker.controller.state === 'activated'");
    try run(browser,
        \\globalThis.state.changes = 0;
        \\globalThis.state.redundant = false;
        \\navigator.serviceWorker.controller.addEventListener('statechange', e => {
        \\  if (e.target.state === 'redundant') globalThis.state.redundant = true;
        \\});
    );
}

const Shared = struct {
    /// Both pages are controlled.
    ready: [2]std.atomic.Value(bool) = .{ .init(false), .init(false) },
    /// The fetching thread ran A's handler.
    cleared: std.atomic.Value(bool) = .init(false),
    /// A's clearer, published by A's side once its page is controlled.
    clearer: ?fetch.network.NetworkContext.SiteDataClearer = null,
    /// Either side failed: nobody waits for it.
    abandoned: std.atomic.Value(bool) = .init(false),
};

const Side = struct {
    shared: *Shared,
    index: usize,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn main(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            self.shared.abandoned.store(true, .release);
            self.shared.cleared.store(true, .release);
            for (&self.shared.ready) |*ready| ready.store(true, .release);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try browser_mod.Browser.init(self.debug_allocator.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try controlledPage(browser);
        if (self.index == 0) {
            const network = browser.scope.existing(fetch.network.NetworkContext) orelse return error.NoNetwork;
            self.shared.clearer = network.site_data orelse return error.NoClearer;
        }
        self.shared.ready[self.index].store(true, .release);
        if (self.index == 0) return self.cleared(browser);
        return self.keptOwn(browser);
    }

    /// Browser A: its page hears the clear on its own thread.
    fn cleared(self: *Side, browser: *browser_mod.Browser) !void {
        try pumpUntil(browser, &self.shared.cleared);
        if (self.shared.abandoned.load(.acquire)) return;
        try waitFor(browser, "globalThis.state.changes === 1 && navigator.serviceWorker.controller === null && globalThis.state.redundant");
        try run(browser, "navigator.serviceWorker.getRegistrations().then(r => { globalThis.state.count = r.length; });");
        try waitFor(browser, "globalThis.state.count === 0");
    }

    /// Browser B: registers another scope while A is cleared, and keeps both.
    fn keptOwn(self: *Side, browser: *browser_mod.Browser) !void {
        try run(browser, "navigator.serviceWorker.register('/b/sw.js', { scope: '/b/' }).then(r => { globalThis.state.second = r; });");
        try pumpUntil(browser, &self.shared.cleared);
        if (self.shared.abandoned.load(.acquire)) return;
        try waitFor(browser, "globalThis.state.second && globalThis.state.second.active && globalThis.state.second.active.state === 'activated'");
        try run(browser, "navigator.serviceWorker.getRegistrations().then(r => { globalThis.state.count = r.length; });");
        try waitFor(browser, "globalThis.state.count === 2");
        if (!try truthy(browser, "globalThis.state.changes === 0 && !globalThis.state.redundant && navigator.serviceWorker.controller !== null")) {
            return error.TheOtherBrowsersClearReachedThisOne;
        }
    }
};

test "Clear-Site-Data on one Browser's fetching thread clears its registrations, and not another Browser's of the same origin" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared, .index = 0 }, .{ .shared = &shared, .index = 1 } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.main, .{side});

    // This thread is the fetching thread: neither Browser's.
    var spins: usize = 0;
    while (!(shared.ready[0].load(.acquire) and shared.ready[1].load(.acquire))) : (spins += 1) {
        if (spins > 60_000) break;
        std.Io.sleep(testing.io, .fromMilliseconds(1), .awake) catch {};
    }
    if (!shared.abandoned.load(.acquire)) {
        if (shared.clearer) |clearer| clearer.clear(clearer.context, origin, .{ .storage = true });
    }
    shared.cleared.store(true, .release);

    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| {
        std.debug.print("Browser {c} failed: {s}\n", .{ "AB"[side.index], @errorName(err) });
        return err;
    };
}
