//! Two whole Browsers on two threads at once, one origin, sharing nothing
//! (instances-design 6.1; instances B1). Since B1 each Browser's platform
//! objects come from its own slab and arena and its DOM side tables are its
//! own (runtime.BrowserScope), so two Browsers can be alive together - inst3's
//! tests (instances_isolation_test.zig) could only run them one after the
//! other.
//!
//! Both Browsers show a page of one origin and write what a profile keeps -
//! localStorage, a cookie, an IndexedDB record, a blob URL - then, while
//! both are alive, each reads back only its own: the other's blob URL is a
//! network error to it. Both then churn DOM objects and their wrappers and
//! navigate, at once; one ends while the other keeps working, and the other
//! still sees all of its own state.
//!
//! Nothing is serialized: both Browsers make window realms (Browser.init,
//! each navigation) whenever they get to them. The pages stay off the V8
//! adapter's state that is still one per process (instances B2): no for-of
//! over platform iterators, no Intl, no async iteration, no ShadowRealm.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

/// One origin for both Browsers.
const page_url = "http://inst4.test/page.html";

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// Show a page of the origin (no network: the page's markup is given).
fn openPage(browser: *browser_mod.Browser) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=root></div></body>", .{ .base_url = page_url });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

/// The two threads' meeting points, and what they hand each other.
const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),
    /// Each Browser's blob URL, for the other's fetch. OWNED (testing.allocator).
    urls: [2]?[]u8 = .{ null, null },
    /// Browser 0 has ended.
    first_ended: std.atomic.Value(bool) = .init(false),

    /// Wait until both threads have arrived at meeting point `point` (1, 2..).
    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 20_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,

    fn id(self: *const Side) []const u8 {
        return if (self.index == 0) "A" else "B";
    }

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            // Whatever happened, never leave the other side waiting.
            _ = self.shared.arrived.fetchAdd(2, .acq_rel);
            self.shared.first_ended.store(true, .release);
        };
    }

    fn script(self: *const Side, buffer: []u8, comptime format: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, format, .{self.id()});
    }

    /// Everything this Browser wrote reads back as its own.
    fn expectOwnState(self: *const Side, browser: *browser_mod.Browser) !void {
        var buffer: [256]u8 = undefined;
        try expectScript(browser, try self.script(&buffer, "localStorage.getItem('k') === '{s}'"));
        try expectScript(browser, try self.script(&buffer, "document.cookie === 'k={s}'"));
    }

    /// Make and drop DOM objects and their wrappers, and collect.
    fn churn(browser: *browser_mod.Browser) !void {
        try expectScript(browser,
            \\{
            \\const root = document.getElementById('root');
            \\for (let i = 0; i < 50; i++) {
            \\  root.innerHTML = '<p class=x><b>one</b><i>two</i></p>'.repeat(4);
            \\  const kept = root.querySelectorAll('.x');
            \\  const extra = document.createElement('span');
            \\  extra.setAttribute('data-i', String(i));
            \\  root.appendChild(extra);
            \\  extra.remove();
            \\  if (kept.length !== 4 || kept[0].firstChild.textContent !== 'one') throw new Error('churn');
            \\}
            \\root.textContent = '';
            \\TestUtils.gc();
            \\}
            \\true
        );
    }

    fn steps(self: *Side) !void {
        const shared = self.shared;
        var buffer: [512]u8 = undefined;
        const browser = try startBrowser();
        var ended = false;
        defer if (!ended) browser.deinit();
        try openPage(browser);

        // What a profile keeps, written while the other Browser writes its own.
        try expectScript(browser, try self.script(&buffer, "localStorage.setItem('k', '{s}'); true"));
        try expectScript(browser, try self.script(&buffer, "document.cookie = 'k={s}; path=/'; true"));
        try expectScript(browser, try self.script(&buffer,
            \\globalThis.stored = null;
            \\{{
            \\const request = indexedDB.open('inst4');
            \\request.onupgradeneeded = () => request.result.createObjectStore('s');
            \\request.onsuccess = () => {{
            \\  const db = request.result;
            \\  const tx = db.transaction('s', 'readwrite');
            \\  tx.objectStore('s').put('{s}', 'who');
            \\  tx.oncomplete = () => {{ db.close(); stored = true; }};
            \\}};
            \\request.onerror = () => stored = String(request.error);
            \\}}
            \\true
        ));
        try waitFor(browser, "stored === true");
        try expectScript(browser, try self.script(&buffer, "globalThis.own_url = URL.createObjectURL(new Blob(['{s}'])); true"));
        {
            const page = browser.current_context orelse return error.NoPage;
            shared.urls[self.index] = try page.evaluateScriptToString("own_url", testing.allocator);
        }

        // Both Browsers alive, both written.
        try shared.meet(1);

        // Each reads only its own: the other's writes, to the same origin,
        // are not here.
        try self.expectOwnState(browser);
        try expectScript(browser,
            \\globalThis.read = null;
            \\{
            \\const request = indexedDB.open('inst4');
            \\request.onsuccess = () => {
            \\  const db = request.result;
            \\  const get = db.transaction('s').objectStore('s').get('who');
            \\  get.onsuccess = () => { read = get.result; db.close(); };
            \\};
            \\}
            \\true
        );
        try waitFor(browser, "read !== null");
        try expectScript(browser, try self.script(&buffer, "read === '{s}'"));
        const other_url = shared.urls[1 - self.index] orelse return error.NoOtherURL;
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "globalThis.other_url = '{s}'; true", .{other_url}));
        try expectScript(browser,
            \\globalThis.results = {};
            \\for (const [key, url] of [['other', other_url], ['own', own_url]])
            \\  fetch(url).then(r => r.text()).then(t => results[key] = t, () => results[key] = 'network error');
            \\true
        );
        try waitFor(browser, "'other' in results && 'own' in results");
        try expectScript(browser, "results.other === 'network error'");
        try expectScript(browser, try self.script(&buffer, "results.own === '{s}'"));

        // Both churn and navigate at once.
        for (0..12) |round| {
            try churn(browser);
            if (round % 4 == 3) {
                try openPage(browser);
                try self.expectOwnState(browser);
            }
        }

        try shared.meet(2);

        if (self.index == 0) {
            // A ends while B is still working.
            ended = true;
            browser.deinit();
            shared.first_ended.store(true, .release);
            return;
        }
        // B, after A's end: its objects, wrappers and state are its own.
        var spins: usize = 0;
        while (!shared.first_ended.load(.acquire)) : (spins += 1) {
            try churn(browser);
            if (spins > 10_000) return error.TheOtherBrowserNeverEnded;
        }
        try churn(browser);
        try self.expectOwnState(browser);
        try openPage(browser);
        try self.expectOwnState(browser);
        try churn(browser);
    }
};

test "two Browsers on two threads at once, one origin, share nothing - and one's end leaves the other working" {
    var shared: Shared = .{};
    defer for (shared.urls) |maybe| if (maybe) |url| testing.allocator.free(url);
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
