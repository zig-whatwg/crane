//! Two Browsers on two threads, each with a page at the same URL, the same
//! service worker registered for it, and the same cookie change subscription
//! (lane sw1-b9): a cookie one Browser sets wakes only its own registration's
//! worker - Cookie Store "process cookie changes" reaches the registrations
//! of the Browser whose jar changed (each Browser's jar, CookieStore
//! listeners and service worker manager are its own), never another's.
//!
//! The worker is the real one (run.zig starts it and fires its cookiechange
//! event); only the script fetch is the test's: it answers from a table.
//! Each Browser allocates from a DebugAllocator of its own, without stack
//! traces (docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md),
//! which still fails the test on a leak.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const sw = @import("service_worker");
const registry = sw.registry;

const page_url = "https://sw-cookies.test/page.html";

/// The worker tells every client of its origin what each cookiechange event
/// carried, and holds the event open until it has.
const worker_script =
    \\self.addEventListener('cookiechange', e => {
    \\  const changed = e.changed.map(c => c.name + '=' + c.value).join(',');
    \\  const deleted = e.deleted.map(c => c.name + ('value' in c ? '=' + c.value : '')).join(',');
    \\  const kind = (e instanceof ExtendableCookieChangeEvent) && (e instanceof ExtendableEvent) && e.isTrusted;
    \\  e.waitUntil(self.clients.matchAll({ includeUncontrolled: true }).then(cs => {
    \\    for (const c of cs) c.postMessage('cookiechange ' + kind + ' ' + changed + '|' + deleted);
    \\  }));
    \\});
;

const test_host: sw.manager.Host = .{
    .fetch = tableFetch,
    .start = sw.run.host.start,
    .dispatch = sw.run.host.dispatch,
    .post_message = sw.run.host.post_message,
    .dispatch_fetch = sw.run.host.dispatch_fetch,
    .dispatch_functional = sw.run.host.dispatch_functional,
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

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 2000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    const context = browser.current_context orelse return error.TimedOut;
    const state = context.evaluateScriptToString("String(globalThis.state) + ' heard: ' + JSON.stringify(globalThis.heard)", testing.allocator) catch return error.TimedOut;
    defer testing.allocator.free(state);
    std.debug.print("timed out waiting for: {s}\n  {s}\n", .{ source, state });
    return error.TimedOut;
}

/// Turn the loop for about `ms` milliseconds.
fn turnFor(browser: *browser_mod.Browser, ms: usize) !void {
    var turns: usize = 0;
    while (turns < ms / 10) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    shared: *Shared,
    /// The value this Browser sets, and when: "A" first, "B" second.
    value: []const u8,
    first: bool,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try browser_mod.Browser.init(self.debug_allocator.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
        try waitFor(browser, "document.readyState === 'complete'");
        const realm = browser.getRealm() orelse return error.NoRealm;
        const manager = sw.Manager.of(realm) orelse return error.NoManager;
        manager.host = &test_host;

        const started = try browser.evaluateScript(
            \\globalThis.heard = [];
            \\globalThis.state = 'registering';
            \\navigator.serviceWorker.onmessage = e => heard.push(e.data);
            \\navigator.serviceWorker.register('/sw.js')
            \\  .then(() => navigator.serviceWorker.ready)
            \\  .then(r => r.cookies.subscribe([{ name: 'shared' }]).then(() => r.cookies.getSubscriptions()))
            \\  .then(s => { globalThis.state = 'subscribed ' + s.map(x => x.name + '@' + x.url).join(); },
            \\        e => { globalThis.state = 'failed ' + e; });
        );
        started.release();
        try waitFor(browser, "globalThis.state === 'subscribed shared@https://sw-cookies.test/'");

        // 1. Both are subscribed; the first Browser sets the cookie.
        try self.shared.meet(1);
        const expect_own = try std.fmt.allocPrint(self.debug_allocator.allocator(), "heard.length === 1 && heard[0] === 'cookiechange true shared={s}|'", .{self.value});
        defer self.debug_allocator.allocator().free(expect_own);
        if (self.first) {
            if (!try truthy(browser, try setCookie(self.value))) return error.SetFailed;
            try waitFor(browser, expect_own);
        }
        // 2. The other has turned its loop long enough to have heard it,
        // had it reached its worker: it did not.
        try self.shared.meet(2);
        if (!self.first) {
            try turnFor(browser, 300);
            if (!try truthy(browser, "heard.length === 0")) return error.HeardTheOtherBrowsersCookie;
            // Its own change reaches its own worker.
            if (!try truthy(browser, try setCookie(self.value))) return error.SetFailed;
            try waitFor(browser, expect_own);
        }
        try self.shared.meet(3);
        if (self.first) {
            try turnFor(browser, 300);
            if (!try truthy(browser, expect_own)) return error.HeardTheOtherBrowsersCookie;
        }
        try self.shared.meet(4);
        _ = try browser.runEventLoopBlocking(20);
    }

    fn setCookie(value: []const u8) ![]const u8 {
        return if (std.mem.eql(u8, value, "A")) "(document.cookie = 'shared=A', true)" else "(document.cookie = 'shared=B', true)";
    }
};

test "a cookie change in one Browser wakes only its own registration's worker, on two threads" {
    var shared: Shared = .{};
    var sides = [_]Side{
        .{ .shared = &shared, .value = "A", .first = true },
        .{ .shared = &shared, .value = "B", .first = false },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
