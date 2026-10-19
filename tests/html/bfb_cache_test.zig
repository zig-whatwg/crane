//! The back/forward cache (lane bfcache-b, phase B): a noopener popup's page
//! is kept when its navigation leaves it and shown again, unfetched, by a
//! traversal back - its realm, its JS heap, its timers paused - and leaves
//! the cache by size, by age, by a delivery it cannot answer, by its
//! traversable closing and by the Browser's end. And what keeps a page out:
//! the eligibility matrix (dom.bfcache.mayKeep and the navigable's part).
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! the Browser's proxy, so their URLs are HTTP and their responses 200 - what
//! a kept page needs. The popup is found through the Browser's navigables: a
//! noopener window.open() returns null, and an opener would keep it out.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const html = @import("html");
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;
const BackForwardCache = browser_mod.back_forward_cache.BackForwardCache;

const host_url = "http://bfb.test/host.html";

/// A page that logs its page transition events and counts its loads.
fn page(comptime name: []const u8, comptime extra: []const u8) []const u8 {
    return "<!doctype html><title>" ++ name ++ "</title><script>" ++
        "var log = []; var loads = (globalThis.loads || 0) + 1;" ++
        "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));" ++
        "addEventListener('pagehide', e => log.push('pagehide:' + e.persisted));" ++
        extra ++ "</script>";
}

const routes = [_]http.Route{
    .{ .path = "/a.html", .content_type = "text/html", .body = page("a", "") },
    .{ .path = "/b.html", .content_type = "text/html", .body = page("b", "") },
    .{ .path = "/c.html", .content_type = "text/html", .body = page("c", "") },
    .{ .path = "/d.html", .content_type = "text/html", .body = page("d", "") },
    // A page whose script runs a timer it set before it was left.
    .{ .path = "/timer.html", .content_type = "text/html", .body = page("timer", "var fired = 0; function arm(ms) { setTimeout(() => { fired = performance.now(); }, ms); }") },
    // A page that listens on a BroadcastChannel.
    .{ .path = "/channel.html", .content_type = "text/html", .body = page("channel", "var heard = 0; new BroadcastChannel('bfb').onmessage = () => { heard++; };") },
    // A page that holds a Web Lock until it is destroyed.
    .{ .path = "/lock.html", .content_type = "text/html", .body = page("lock", "navigator.locks.request('bfb-lock', () => new Promise(() => {}));") },
    // A page with a frame: phase B keeps no page with child navigables.
    .{ .path = "/frame.html", .content_type = "text/html", .body = page("frame", "") ++ "<iframe srcdoc='<p>child'></iframe>" },
    // A page with an RTCPeerConnection (Chromium's "rtc").
    .{ .path = "/rtc.html", .content_type = "text/html", .body = page("rtc", "var pc = new RTCPeerConnection();") },
    // A page that a 404 answers.
    .{ .path = "/missing.html", .content_type = "text/html", .body = page("missing", ""), .fail_first = 1000 },
    // A page that runs a dedicated worker, and one that connects to a shared worker.
    .{ .path = "/worker.html", .content_type = "text/html", .body = page("worker", "var w = new Worker('/w.js');") },
    .{ .path = "/shared.html", .content_type = "text/html", .body = page("shared", "var s = new SharedWorker('/w.js');") },
    .{ .path = "/w.js", .content_type = "text/javascript", .body = "onmessage = () => {};" },
    // A page that posts a form to /a.html: what it shows is a POST's response.
    // (Submitted once the page has completely loaded: a navigation before
    // that is a replace, which would leave no entry for the page.)
    .{ .path = "/post.html", .content_type = "text/html", .body = "<!doctype html><form method=post action=/a.html><input name=x value=1></form><script>onload = () => setTimeout(() => document.forms[0].submit(), 0);</script>" },
    // A page still loading (its image answers late) when it is left.
    .{ .path = "/loading.html", .content_type = "text/html", .body = page("loading", "") ++ "<img src=/slow.png>" },
    .{ .path = "/slow.png", .content_type = "image/png", .body = "", .delay_ms = 1500 },
};

const Fixture = struct {
    allocator: std.mem.Allocator,
    server: *http.Server,
    browser: *Browser,
    proxy_buf: [64]u8 = undefined,

    fn start(config: browser_mod.BrowserConfig) !*Fixture {
        return startWith(testing.allocator, config);
    }

    /// A fixture whose Browser and server use `allocator` (a thread's own,
    /// for the two-thread test).
    fn startWith(allocator: std.mem.Allocator, config: browser_mod.BrowserConfig) !*Fixture {
        const self = try allocator.create(Fixture);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.server = try http.Server.start(allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        var with_proxy = config;
        with_proxy.persist_storage = false;
        with_proxy.snapshot_path = "";
        with_proxy.proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } };
        self.browser = try Browser.init(allocator, with_proxy);
        errdefer self.browser.deinit();
        try self.browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
        const context = self.browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><p>host", .{ .base_url = host_url });
        return self;
    }

    fn stop(self: *Fixture) void {
        self.browser.deinit();
        self.server.stop();
        self.allocator.destroy(self);
    }

    fn cache(self: *Fixture) ?*BackForwardCache {
        return self.browser.scope.existing(BackForwardCache);
    }

    fn cached(self: *Fixture) usize {
        const c = self.cache() orelse return 0;
        return c.count();
    }

    fn turn(self: *Fixture, ms: u64) !void {
        _ = try self.browser.runEventLoopBlocking(ms);
    }

    /// Open `path` in a noopener popup and wait for it to load: the
    /// popup's browsing context.
    fn openPopup(self: *Fixture, comptime path: []const u8) !*html.BrowsingContext {
        return self.openPopupAt("http://bfb.test", path);
    }

    /// `openPopup` on `origin` - http://localhost is a secure context, which
    /// Web Locks needs.
    fn openPopupAt(self: *Fixture, comptime origin: []const u8, comptime path: []const u8) !*html.BrowsingContext {
        const opened = try self.browser.evaluateScript("window.open('" ++ origin ++ path ++ "', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (self.popup()) |bc| {
                if (try self.popupIs(bc, path)) return bc;
            }
            try self.turn(10);
        }
        return error.TimedOut;
    }

    /// The Browser's one top-level browsing context besides the host page's.
    fn popup(self: *Fixture) ?*html.BrowsingContext {
        const realm = self.browser.getRealm() orelse return null;
        const navigables = dom.browser_state.navigablesOf(realm) orelse return null;
        const host_window = hostWindow(self.browser) orelse return null;
        const host_bc = dom.browser_state.browsingContextOf(host_window);
        for (navigables.contexts()) |bc| {
            if (bc.parent != null or bc.orphaned or bc.is_closed) continue;
            if (host_bc != null and bc == host_bc.?) continue;
            return bc;
        }
        return null;
    }

    /// Whether `bc` shows a loaded document at `path`.
    fn popupIs(self: *Fixture, bc: *html.BrowsingContext, comptime path: []const u8) !bool {
        _ = self;
        const realm = activeRealm(bc) orelse return false;
        const answer = try evaluateIn(realm, "document.readyState === 'complete' && location.pathname === '" ++ path ++ "'");
        defer testing.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }

    /// Run `source` in `bc`'s active realm, then turn the loop until `bc`
    /// shows `path`.
    fn goTo(self: *Fixture, bc: *html.BrowsingContext, comptime source: []const u8, comptime path: []const u8) !void {
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const ran = try evaluateIn(realm, source);
        testing.allocator.free(ran);
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            try self.turn(10);
            if (try self.popupIs(bc, path)) {
                // The commit's own tasks (pageshow and the like) run first.
                try self.turn(20);
                return;
            }
        }
        return error.TimedOut;
    }
};

fn hostWindow(browser: *Browser) ?*runtime.Instance {
    const realm = browser.getRealm() orelse return null;
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

fn activeRealm(bc: *html.BrowsingContext) ?runtime.Context {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return null));
    return window.ctx;
}

fn logReporter(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

/// `source` evaluated in `realm`, ToString'd: owned by testing.allocator.
fn evaluateIn(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
}

/// Whether `realm` answers `source` with "true".
fn isTrue(realm: runtime.Context, source: []const u8) !bool {
    const answer = try evaluateIn(realm, source);
    defer testing.allocator.free(answer);
    return std.mem.eql(u8, answer, "true");
}

fn expectIn(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const answer = try evaluateIn(realm, source);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings(expected, answer);
}

test "a noopener popup's page is kept when it navigates, and a traversal back shows it again, unfetched, persisted" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "loads", "1");

    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    // A new realm for B, with a WindowProxy of its own: A's realm lives on.
    const realm_b = activeRealm(bc).?;
    try testing.expect(realm_b != realm_a);
    try testing.expect(realm_a.hasEngine());

    try fixture.goTo(bc, "history.back()", "/a.html");
    // The same realm, its heap as it was: not fetched, not run again.
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try testing.expectEqual(@as(u32, 1), fixture.server.count("/a.html"));
    try expectIn(realm_a, "loads", "1");
    try expectIn(realm_a, "log.join()", "pageshow:false,pagehide:true,pageshow:true");
    // B was kept in its turn (navigate-history-back-bfcache.html needs it).
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    try fixture.goTo(bc, "history.forward()", "/b.html");
    try testing.expectEqual(realm_b, activeRealm(bc).?);
    try testing.expectEqual(@as(u32, 1), fixture.server.count("/b.html"));
}

test "a kept page's timer waits while it is cached and runs after it is restored" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopup("/timer.html");
    const realm = activeRealm(bc).?;
    const armed = try evaluateIn(realm, "arm(300); performance.now()");
    defer testing.allocator.free(armed);
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    // Cached for longer than the timer's wait: it does not fire meanwhile.
    try fixture.turn(500);
    try fixture.goTo(bc, "history.back()", "/timer.html");
    try expectIn(realm, "fired", "0");
    // It had most of its wait left: it fires once that has passed.
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        try fixture.turn(10);
        const fired = try evaluateIn(realm, "fired > 0");
        defer testing.allocator.free(fired);
        if (std.mem.eql(u8, fired, "true")) break;
    }
    try expectIn(realm, "fired > 0", "true");
}

test "the cache keeps at most its size, the oldest leaving first" {
    const fixture = try Fixture.start(.{ .back_forward_cache_size = 2 });
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try fixture.goTo(bc, "location.href = '/c.html'", "/c.html");
    try testing.expectEqual(@as(usize, 2), fixture.cached());
    try fixture.goTo(bc, "location.href = '/d.html'", "/d.html");
    // A's eviction is a task: the next turn ends its realm.
    try fixture.turn(20);
    try testing.expectEqual(@as(usize, 2), fixture.cached());
    try testing.expect(!realm_a.hasEngine());
}

test "a page leaves the cache after its time to live, and a traversal back fetches it again" {
    const fixture = try Fixture.start(.{ .back_forward_cache_ttl_seconds = 1 });
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    try fixture.turn(1300);
    try testing.expectEqual(@as(usize, 0), fixture.cached());
    try fixture.goTo(bc, "history.back()", "/a.html");
    try testing.expectEqual(@as(u32, 2), fixture.server.count("/a.html"));
}

test "a cache of size 0 keeps nothing" {
    const fixture = try Fixture.start(.{ .back_forward_cache_size = 0 });
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 0), fixture.cached());
}

test "a BroadcastChannel message to a cached page evicts it instead of running its listener" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopup("/channel.html");
    const realm = activeRealm(bc).?;
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    const posted = try evaluateIn(activeRealm(bc).?, "new BroadcastChannel('bfb').postMessage('hi'); 'posted'");
    testing.allocator.free(posted);
    try fixture.turn(50);
    try testing.expectEqual(@as(usize, 0), fixture.cached());
    try testing.expect(!realm.hasEngine());
}

test "the page that opened a popup ending evicts its cached pages first" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    // Browser.navigate replaces the host page: its popup's cached page goes
    // first, while its realm and the loop live.
    try fixture.browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
    try testing.expectEqual(@as(usize, 0), fixture.cached());
    try testing.expect(!realm_a.hasEngine());
}

test "a Browser that ends with two cached pages leaks nothing" {
    const fixture = try Fixture.start(.{});
    const bc = try fixture.openPopup("/a.html");
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try fixture.goTo(bc, "location.href = '/c.html'", "/c.html");
    try testing.expectEqual(@as(usize, 2), fixture.cached());
    // testing.allocator reports what their eviction leaks.
    fixture.stop();
}

/// Open `path` in a popup, navigate it to /b.html, and say whether the
/// cache kept the page it left.
fn keptAfterLeaving(comptime path: []const u8, comptime then: []const u8) !bool {
    return keptAfterLeavingAt("http://bfb.test", path, then);
}

fn keptAfterLeavingAt(comptime origin: []const u8, comptime path: []const u8, comptime then: []const u8) !bool {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopupAt(origin, path);
    try fixture.goTo(bc, "location.href = '/b.html'", then);
    return fixture.cached() > 0;
}

test "the eligibility matrix: a page that holds a lock, has a frame, a worker or a shared worker is not kept" {
    try testing.expect(try keptAfterLeaving("/a.html", "/b.html"));
    // Web Locks are [SecureContext]: the page holds its lock on localhost.
    try testing.expect(try keptAfterLeavingAt("http://localhost", "/a.html", "/b.html"));
    try testing.expect(!try keptAfterLeavingAt("http://localhost", "/lock.html", "/b.html"));
    try testing.expect(!try keptAfterLeaving("/frame.html", "/b.html"));
    try testing.expect(!try keptAfterLeaving("/worker.html", "/b.html"));
    try testing.expect(!try keptAfterLeaving("/shared.html", "/b.html"));
    try testing.expect(!try keptAfterLeaving("/rtc.html", "/b.html"));
}

test "the eligibility matrix: a 404, a POST's response and a page still loading are not kept" {
    {
        const fixture = try Fixture.start(.{});
        defer fixture.stop();
        const opened = try fixture.browser.evaluateScript("window.open('http://bfb.test/missing.html', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (fixture.popup() == null and turns < 200) : (turns += 1) try fixture.turn(10);
        const bc = fixture.popup() orelse return error.NoPopup;
        var settled: usize = 0;
        while (settled < 200) : (settled += 1) {
            const realm = activeRealm(bc) orelse break;
            if (try isTrue(realm, "location.pathname === '/missing.html' && document.readyState === 'complete'")) break;
            try fixture.turn(10);
        }
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        try testing.expectEqual(@as(usize, 0), fixture.cached());
    }
    {
        // /post.html submits to /a.html: the page left is a POST's.
        const fixture = try Fixture.start(.{});
        defer fixture.stop();
        const bc = try fixture.openPopup("/post.html");
        var turns: usize = 0;
        while (turns < 300) : (turns += 1) {
            if (try fixture.popupIs(bc, "/a.html")) break;
            try fixture.turn(10);
        }
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        // /post.html itself was kept (a GET); the POST's /a.html was not.
        try testing.expectEqual(@as(usize, 1), fixture.cached());
    }
    {
        const fixture = try Fixture.start(.{});
        defer fixture.stop();
        const opened = try fixture.browser.evaluateScript("window.open('http://bfb.test/loading.html', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (turns < 300) : (turns += 1) {
            if (fixture.popup()) |bc| if (activeRealm(bc)) |realm| {
                if (try isTrue(realm, "location.pathname === '/loading.html' && document.readyState !== 'complete'")) break;
            };
            try fixture.turn(10);
        }
        const bc = fixture.popup() orelse return error.NoPopup;
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        try testing.expectEqual(@as(usize, 0), fixture.cached());
    }
}

test "a popup with an opener is not kept" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const opened = try fixture.browser.evaluateScript("globalThis.bfbPopup = window.open('http://bfb.test/a.html', 'bfb')");
    opened.release();
    var turns: usize = 0;
    while (turns < 300) : (turns += 1) {
        if (try isTrue(fixture.browser.getRealm().?, "bfbPopup.document?.readyState === 'complete' && bfbPopup.location.pathname === '/a.html'")) break;
        try fixture.turn(10);
    }
    const bc = fixture.popup() orelse return error.NoPopup;
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 0), fixture.cached());
}

/// One thread's Browser for the two-thread test: its own leak-checking
/// allocator (AGENTS.md: a shared testing.allocator makes the threads take
/// turns).
const ThreadRun = struct {
    failed: bool = false,
    leaked: bool = false,
    caching: bool,

    fn body(self: *ThreadRun) void {
        var counted: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        self.run(counted.allocator()) catch {
            self.failed = true;
        };
        self.leaked = counted.deinit() == .leak;
    }

    fn run(self: *ThreadRun, allocator: std.mem.Allocator) !void {
        const fixture = try Fixture.startWith(allocator, .{ .back_forward_cache_size = 1 });
        defer fixture.stop();
        if (!self.caching) {
            // Tasks and timers, while the other thread caches pages.
            const busy = try fixture.browser.evaluateScript("globalThis.done = 0; for (let i = 0; i < 200; i++) { setTimeout(() => done++, i % 7); postMessage('x', '*'); } 'ok'");
            busy.release();
            var turns: usize = 0;
            while (turns < 500) : (turns += 1) {
                if (try isTrue(fixture.browser.getRealm().?, "done === 200")) return;
                try fixture.turn(5);
            }
            return error.TimedOut;
        }
        const bc = try fixture.openPopup("/a.html");
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        // Size 1: storing B's leaving page evicts A's.
        try fixture.goTo(bc, "location.href = '/c.html'", "/c.html");
        try fixture.turn(20);
        if (fixture.cached() != 1) return error.NotEvicted;
        try fixture.goTo(bc, "history.back()", "/b.html");
    }
};

test "two Browsers on two threads: one stores, restores and evicts while the other runs tasks" {
    var caching: ThreadRun = .{ .caching = true };
    var busy: ThreadRun = .{ .caching = false };
    const a = try std.Thread.spawn(.{}, ThreadRun.body, .{&caching});
    const b = try std.Thread.spawn(.{}, ThreadRun.body, .{&busy});
    a.join();
    b.join();
    try testing.expect(!caching.failed and !busy.failed);
    try testing.expect(!caching.leaked and !busy.leaked);
}

test "the eligibility matrix: unload listeners do not keep a page out (Chrome, Safari)" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "addEventListener('unload', () => { localStorage.bfbUnload = 1; }); 'ok'", "ok");
    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    try fixture.goTo(bc, "history.back()", "/a.html");
    // Kept, so its unload event never fired (unload step 12).
    try expectIn(realm_a, "String(localStorage.bfbUnload)", "undefined");
}
