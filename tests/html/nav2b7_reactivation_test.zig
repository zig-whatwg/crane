//! Lane nav2 batch 7, cause C: the navigation API's part of a page shown again
//! from the back/forward cache (Chromium's NavigationApi::SetEntriesForRestore).
//!
//! - HTML "update document for history step application" step 7 on the
//!   document's EXISTING NavigationActivation: the same object, now "traverse",
//!   whose old entry is the entry the traversal left - null when that entry is
//!   not in the restored document's entry list (another origin's)
//!   (navigation-activation/activation-after-bfcache-cross-origin-clears-from).
//! - "Reactivate" step 3, "update the navigation API entries for
//!   reactivation": an entry the page had handed out whose session history
//!   entry went while the page was cached fires dispose, from a task, after
//!   pageshow (per-entry-events/dispose-after-bfcache).
//! - A cross-document navigate() whose navigate event was left ongoing when
//!   the page was kept is dropped at the restore: the page's next navigation
//!   fires no navigateerror and the promise stays pending (navigate-event/
//!   dangling-navigate-event-after-bfcache-restore; Chrome and Firefox).
//!
//! Pages come from a loopback HTTP server through the Browser's proxy (as in
//! bfb_cache_test.zig): a kept page needs an HTTP 200 response. The Browser's
//! end after the restores is leak-checked by testing.allocator.
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

const host_url = "http://nav2b7.test/host.html";

const plain = "<!doctype html><title>page</title><script>var log = [];" ++
    "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));</script>";

const routes = [_]http.Route{
    .{ .path = "/a.html", .content_type = "text/html", .body = plain },
    .{ .path = "/b.html", .content_type = "text/html", .body = plain },
    .{ .path = "/c.html", .content_type = "text/html", .body = plain },
};

const Fixture = struct {
    server: *http.Server,
    browser: *Browser,
    proxy_buf: [64]u8 = undefined,

    fn start() !*Fixture {
        const self = try testing.allocator.create(Fixture);
        errdefer testing.allocator.destroy(self);
        self.server = try http.Server.start(testing.allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        self.browser = try Browser.init(testing.allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
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

    /// Open http://nav2b7.test`path` in a noopener popup, loaded.
    fn openPopup(self: *Fixture, comptime path: []const u8) !*html.BrowsingContext {
        const opened = try self.browser.evaluateScript("window.open('http://nav2b7.test" ++ path ++ "', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (self.popup()) |bc| {
                if (try shows(bc, "/nav2b7.test" ++ path)) return bc;
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

    /// Run `source` in `bc`'s active realm, then turn the loop until `bc`
    /// shows `where` ("/<host><path>"), and its commit's tasks have run.
    fn goTo(self: *Fixture, bc: *html.BrowsingContext, source: []const u8, comptime where: []const u8) !void {
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const ran = try evaluateIn(realm, source);
        testing.allocator.free(ran);
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            try self.turn(10);
            if (try shows(bc, where)) {
                try self.turn(20);
                return;
            }
        }
        return error.TimedOut;
    }
};

/// Whether `bc` shows a loaded document whose "/" ++ host ++ pathname is `where`.
fn shows(bc: *html.BrowsingContext, comptime where: []const u8) !bool {
    const realm = activeRealm(bc) orelse return false;
    return isTrue(realm, "document.readyState === 'complete' && '/' + location.host + location.pathname === '" ++ where ++ "'");
}

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
    if (!std.mem.eql(u8, expected, answer)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, answer });
    try testing.expectEqualStrings(expected, answer);
}

test "a page shown again from the cache keeps its activation object, updated at each restore; the Browser's end frees it" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "window.act = navigation.activation; act !== null", "true");

    // Restore 1: from a same-origin page - its entry is in A's entry list.
    try fixture.goTo(bc, "location.href = '/b.html'", "/nav2b7.test/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    try fixture.goTo(bc, "history.back()", "/nav2b7.test/a.html");
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try expectIn(realm_a, "navigation.activation === act", "true");
    try expectIn(realm_a, "act.navigationType", "traverse");
    try expectIn(realm_a, "act.entry === navigation.currentEntry", "true");
    try expectIn(realm_a, "new URL(act.from.url).pathname", "/b.html");

    // Restore 2: from another origin - its entry is not in A's list.
    try fixture.goTo(bc, "location.href = 'http://other.nav2b7.test/c.html'", "/other.nav2b7.test/c.html");
    try fixture.goTo(bc, "history.back()", "/nav2b7.test/a.html");
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try expectIn(realm_a, "navigation.activation === act", "true");
    try expectIn(realm_a, "act.navigationType + ' ' + (act.from === null)", "traverse true");
    try expectIn(realm_a, "act.entry === navigation.currentEntry", "true");
}

test "an entry that went while the page was cached fires dispose after the restore's pageshow" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    // A fragment entry, then back on it: entries()[1] is the fragment's.
    const ran = try evaluateIn(realm_a, "navigation.navigate('#1').finished.then(() => navigation.back().finished).then(() => {" ++
        " window.forward = navigation.entries()[1];" ++
        " forward.ondispose = () => log.push('dispose');" ++
        " window.ready = true; })");
    testing.allocator.free(ran);
    var turns: usize = 0;
    while (turns < 300 and !(try isTrue(realm_a, "window.ready === true"))) : (turns += 1) try fixture.turn(10);
    try expectIn(realm_a, "location.hash + ' ' + navigation.entries().length", " 2");

    // A push from the entry before the fragment's clears it from the history.
    try fixture.goTo(bc, "log.length = 0; location.href = '/b.html'", "/nav2b7.test/b.html");
    try fixture.goTo(bc, "history.back()", "/nav2b7.test/a.html");
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try fixture.turn(20);
    try expectIn(realm_a, "log.join()", "pageshow:true,dispose");
    try expectIn(realm_a, "navigation.entries().length + ' ' + navigation.entries().includes(forward)", "2 false");
}

test "a cross-document navigate() left ongoing by the page that was kept is dropped at the restore: no navigateerror, its promise stays pending" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/a.html");
    const realm_a = activeRealm(bc).?;
    try fixture.goTo(bc, "window.errors = 0; window.result = 'pending';" ++
        " navigation.onnavigateerror = () => errors++;" ++
        " navigation.navigate('/b.html').finished.then(() => { result = 'resolved'; }, () => { result = 'rejected'; });", "/nav2b7.test/b.html");
    try fixture.goTo(bc, "history.back()", "/nav2b7.test/a.html");
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    const pushed = try evaluateIn(realm_a, "history.pushState(null, '', '#after')");
    testing.allocator.free(pushed);
    try fixture.turn(30);
    try expectIn(realm_a, "errors + ' ' + result + ' ' + location.hash", "0 pending #after");
}
