//! The back/forward cache keeps a page WITH its frames (lane nav4; bfcache
//! design phase C, tmp/plans/bfcache-design.md): a noopener popup's page with
//! an iframe is kept when it navigates, and a traversal back shows the page
//! and its frame again - the same realms, unfetched, each document shown
//! persisted - while nothing of the frame runs as long as the page is cached;
//! eviction and the Browser's end destroy the kept frames with the page.
//!
//! Chrome 157 and Safari 27.2 keep such a page
//! (history-traversal/pagereveal/order-in-bfcache-restore-iframe.html, PASS on
//! wpt.fyi stable at 2358bd4835; Firefox 160 keeps it too, failing only the
//! pagereveal order).
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! the Browser's proxy, so their URLs are HTTP and their responses 200 - what
//! a kept page needs. tests/html is one executable: the engine may already be
//! started.
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

const host_url = "http://nav4f.test/host.html";

/// A frame document that logs its page transition events, counts its loads,
/// and runs a 0 ms timer chain counting while it is shown.
const frame_page = "<!doctype html><title>frame</title><script>" ++
    "var log = []; var loads = (globalThis.loads || 0) + 1; var ticks = 0;" ++
    "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));" ++
    "addEventListener('pagehide', e => log.push('pagehide:' + e.persisted));" ++
    "function tick() { ticks++; setTimeout(tick, 10); } tick();" ++
    "</script>";

/// A top-level page with one iframe.
const top_page = "<!doctype html><title>top</title><script>" ++
    "var log = []; var loads = (globalThis.loads || 0) + 1;" ++
    "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));" ++
    "addEventListener('pagehide', e => log.push('pagehide:' + e.persisted));" ++
    "</script><iframe src=/frame.html></iframe>";

const routes = [_]http.Route{
    .{ .path = "/top.html", .content_type = "text/html", .body = top_page },
    .{ .path = "/frame.html", .content_type = "text/html", .body = frame_page },
    .{ .path = "/b.html", .content_type = "text/html", .body = "<!doctype html><title>b</title>" },
    .{ .path = "/c.html", .content_type = "text/html", .body = "<!doctype html><title>c</title>" },
};

const Fixture = struct {
    server: *http.Server,
    browser: *Browser,
    proxy_buf: [64]u8 = undefined,

    fn start(config: browser_mod.BrowserConfig) !*Fixture {
        const self = try testing.allocator.create(Fixture);
        errdefer testing.allocator.destroy(self);
        self.server = try http.Server.start(testing.allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        var with_proxy = config;
        with_proxy.snapshot_path = "";
        with_proxy.proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } };
        self.browser = try Browser.init(testing.allocator, with_proxy);
        errdefer self.browser.deinit();
        try self.browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
        const context = self.browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><p>host", .{ .base_url = host_url });
        return self;
    }

    fn stop(self: *Fixture) void {
        self.browser.deinit();
        self.server.stop();
        testing.allocator.destroy(self);
    }

    fn cached(self: *Fixture) usize {
        const c = self.browser.scope.existing(BackForwardCache) orelse return 0;
        return c.count();
    }

    fn turn(self: *Fixture, ms: u64) !void {
        _ = try self.browser.runEventLoopBlocking(ms);
    }

    /// Open /top.html in a noopener popup and wait until it and its frame
    /// have loaded: the popup's browsing context.
    fn openTop(self: *Fixture) !*html.BrowsingContext {
        const opened = try self.browser.evaluateScript("window.open('http://nav4f.test/top.html', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (self.popup()) |bc| {
                if (try shows(bc, "/top.html")) {
                    if (frameRealm(bc)) |frame| {
                        if (try isTrue(frame, "document.readyState === 'complete' && ticks > 2")) return bc;
                    }
                }
            }
            try self.turn(10);
        }
        return error.TimedOut;
    }

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

    fn goTo(self: *Fixture, bc: *html.BrowsingContext, comptime source: []const u8, comptime path: []const u8) !void {
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const ran = try evaluateIn(realm, source);
        testing.allocator.free(ran);
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            try self.turn(10);
            if (try shows(bc, path)) {
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

/// The realm of the first child navigable's active document of `bc`.
fn frameRealm(bc: *html.BrowsingContext) ?runtime.Context {
    if (bc.children.items.len == 0) return null;
    return activeRealm(bc.children.items[0]);
}

fn shows(bc: *html.BrowsingContext, comptime path: []const u8) !bool {
    const realm = activeRealm(bc) orelse return false;
    return isTrue(realm, "document.readyState === 'complete' && location.pathname === '" ++ path ++ "'");
}

fn logReporter(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn evaluateIn(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
}

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

test "a page with a frame is kept with its frame, and a traversal back shows both again, unfetched, persisted" {
    const fixture = try Fixture.start(.{});
    defer fixture.stop();
    const bc = try fixture.openTop();
    const top_a = activeRealm(bc).?;
    const frame_a = frameRealm(bc).?;

    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    // The page that replaced it has no frame: the kept frame is the kept
    // page's, not the navigable's.
    try testing.expectEqual(@as(usize, 0), bc.children.items.len);
    try expectIn(activeRealm(bc).?, "String(window.length)", "0");
    // Nothing of the frame runs while the page is cached: its timers wait.
    const ticks_kept = try evaluateIn(frame_a, "String(ticks)");
    defer testing.allocator.free(ticks_kept);
    try fixture.turn(200);
    try expectIn(frame_a, "String(ticks)", ticks_kept);

    try fixture.goTo(bc, "history.back()", "/top.html");
    // The same realms, their heaps as they were: nothing fetched again.
    try testing.expectEqual(top_a, activeRealm(bc).?);
    try testing.expectEqual(frame_a, frameRealm(bc).?);
    try testing.expectEqual(@as(u32, 1), fixture.server.count("/top.html"));
    try testing.expectEqual(@as(u32, 1), fixture.server.count("/frame.html"));
    try expectIn(top_a, "loads + ':' + window.length + ':' + log.join()", "1:1:pageshow:false,pagehide:true,pageshow:true");
    try expectIn(frame_a, "loads + ':' + log.join()", "1:pageshow:false,pagehide:true,pageshow:true");
    // The frame's parent is its page's Window again, and its timers run again.
    try expectIn(frame_a, "String(parent === top && parent.document.title === 'top')", "true");
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        const ran = try evaluateIn(frame_a, "String(ticks)");
        defer testing.allocator.free(ran);
        if (!std.mem.eql(u8, ran, ticks_kept)) break;
        try fixture.turn(10);
    }
    try testing.expect(turns < 200);
}

test "a kept page with a frame leaves the cache with its frame: by time to live, and with the Browser's end" {
    {
        const fixture = try Fixture.start(.{ .back_forward_cache_ttl_seconds = 1 });
        defer fixture.stop();
        const bc = try fixture.openTop();
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        try testing.expectEqual(@as(usize, 1), fixture.cached());
        try fixture.turn(1300);
        try testing.expectEqual(@as(usize, 0), fixture.cached());
        // Evicted: back fetches the page and its frame again.
        try fixture.goTo(bc, "history.back()", "/top.html");
        try testing.expectEqual(@as(u32, 2), fixture.server.count("/top.html"));
    }
    {
        // A Browser that ends with a kept page and its frame leaks nothing
        // (std.testing.allocator checks).
        const fixture = try Fixture.start(.{});
        defer fixture.stop();
        const bc = try fixture.openTop();
        try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
        try testing.expectEqual(@as(usize, 1), fixture.cached());
    }
}
