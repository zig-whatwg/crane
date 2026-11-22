//! A fetch() in flight when its page is left (lane nav4): what golden rule 2
//! gives where the three browsers differ (wpt.fyi stable at 2358bd4835,
//! back-forward-cache/eligibility/inflight-fetch-*.html), mechanism by
//! mechanism:
//!
//! - the navigation's start cancels the page's fetches (HTML navigate step
//!   24.3, "abort a document"): Firefox (nsDocShell::InternalLoad's
//!   StopInternal(STOP_NETWORK)) and Safari (FrameLoader::
//!   continueLoadAfterNavigationPolicy's stopAllLoaders, which stops the
//!   current document's loader) do; Chrome does not;
//! - the page is kept anyway: Chrome (its fetch goes on) and Safari (its
//!   cancelled loads do not block the cache) keep it; Firefox does not (HTML:
//!   "fetch" makes the document unsalvageable).
//!
//! Together that is Safari's behaviour. An XMLHttpRequest is left in flight by
//! the navigation's start (XMLHttpRequest.zig prepareNavigationDocumentAbort)
//! and ends when its page is stored.
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! the Browser's proxy, so their URLs are HTTP and their responses 200 - what
//! a kept page needs. The popup is noopener (an opener keeps a page out) and
//! is found through the Browser's navigables.
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

const host_url = "http://nav4.test/host.html";

/// A page that logs its page transition events, counts its loads, and
/// starts a fetch of `/held.txt` when asked (`go()`), noting how it ends.
const fetch_page = "<!doctype html><title>fetch</title><script>" ++
    "var log = []; var loads = (globalThis.loads || 0) + 1; var outcome = 'pending';" ++
    "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));" ++
    "addEventListener('pagehide', e => log.push('pagehide:' + e.persisted));" ++
    "function go() { fetch('/held.txt').then(r => r.text()).then(t => { outcome = 'ok:' + t; }, e => { outcome = e.name; }); }" ++
    "</script>";

/// The same page with an XMLHttpRequest instead: `outcome` records its first
/// terminal event, `events` every event it fires.
const xhr_page = "<!doctype html><title>xhr</title><script>" ++
    "var log = []; var loads = (globalThis.loads || 0) + 1; var outcome = 'pending'; var events = [];" ++
    "addEventListener('pageshow', e => log.push('pageshow:' + e.persisted));" ++
    "addEventListener('pagehide', e => log.push('pagehide:' + e.persisted));" ++
    "function go() { const x = new XMLHttpRequest(); x.open('GET', '/held.txt');" ++
    "for (const type of ['readystatechange', 'load', 'error', 'abort', 'loadend'])" ++
    " x.addEventListener(type, () => { events.push(type + ':' + x.readyState); if (outcome === 'pending' && type !== 'readystatechange') outcome = type === 'load' ? 'load:' + x.responseText : type; });" ++
    "x.send(); }" ++
    "</script>";

const routes = [_]http.Route{
    .{ .path = "/fetch.html", .content_type = "text/html", .body = fetch_page },
    .{ .path = "/xhr.html", .content_type = "text/html", .body = xhr_page },
    .{ .path = "/b.html", .content_type = "text/html", .body = "<!doctype html><title>b</title>" },
    // Answered only once the test releases it: a fetch at the server with
    // its response still to come, without betting on a delay.
    .{ .path = "/held.txt", .content_type = "text/plain", .body = "held-body", .held = true },
    // A navigation's response the test holds back the same way.
    .{ .path = "/held-nav.html", .content_type = "text/html", .body = "<!doctype html><title>held</title>", .held = true },
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

    /// Open `path` in a noopener popup and wait for it to load: the popup's
    /// browsing context.
    fn openPopup(self: *Fixture, comptime path: []const u8) !*html.BrowsingContext {
        const opened = try self.browser.evaluateScript("window.open('http://nav4.test" ++ path ++ "', '_blank', 'noopener')");
        opened.release();
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (self.popup()) |bc| {
                if (try popupIs(bc, path)) return bc;
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

    /// Run `source` in `bc`'s active realm, then turn the loop until `bc`
    /// shows `path`.
    fn goTo(self: *Fixture, bc: *html.BrowsingContext, comptime source: []const u8, comptime path: []const u8) !void {
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const ran = try evaluateIn(realm, source);
        testing.allocator.free(ran);
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            try self.turn(10);
            if (try popupIs(bc, path)) {
                // The commit's own tasks (pageshow and the like) run first.
                try self.turn(20);
                return;
            }
        }
        return error.TimedOut;
    }

    /// Turn the loop until the server has had `n` requests for `path`.
    fn awaitRequests(self: *Fixture, comptime path: []const u8, n: u32) !void {
        var turns: usize = 0;
        while (self.server.count(path) < n) : (turns += 1) {
            if (turns >= 500) return error.TimedOut;
            try self.turn(10);
        }
    }

    /// Turn the loop until `realm`'s `outcome` is no longer "pending": what
    /// it is then, owned by testing.allocator.
    fn awaitOutcome(self: *Fixture, realm: runtime.Context) ![]u8 {
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            const outcome = try evaluateIn(realm, "outcome");
            if (!std.mem.eql(u8, outcome, "pending")) return outcome;
            testing.allocator.free(outcome);
            try self.turn(10);
        }
        return error.TimedOut;
    }
};

fn popupIs(bc: *html.BrowsingContext, comptime path: []const u8) !bool {
    const realm = activeRealm(bc) orelse return false;
    const answer = try evaluateIn(realm, "document.readyState === 'complete' && location.pathname === '" ++ path ++ "'");
    defer testing.allocator.free(answer);
    return std.mem.eql(u8, answer, "true");
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

/// `source` evaluated in `realm`, ToString'd: owned by testing.allocator.
fn evaluateIn(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
}

fn expectIn(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const answer = try evaluateIn(realm, source);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings(expected, answer);
}

test "a page left with a fetch in flight is kept, its fetch cancelled with a TypeError as the navigation started (Safari)" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/fetch.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "go(); 'started'", "started");
    try fixture.awaitRequests("/held.txt", 1);

    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    // Kept: the fetch the navigation's start cancelled did not make it
    // unsalvageable (Chrome and Safari keep such a page).
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    // Its answer arrives while the page is cached: the fetch was cancelled,
    // so nothing reaches the page.
    fixture.server.release("/held.txt");
    try fixture.turn(100);

    try fixture.goTo(bc, "history.back()", "/fetch.html");
    // The same realm, not fetched again, shown persisted.
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try testing.expectEqual(@as(u32, 1), fixture.server.count("/fetch.html"));
    try expectIn(realm_a, "loads", "1");
    try expectIn(realm_a, "log.join()", "pageshow:false,pagehide:true,pageshow:true");
    // The cancelled fetch rejected with a TypeError, as a network error does.
    const outcome = try fixture.awaitOutcome(realm_a);
    defer testing.allocator.free(outcome);
    try testing.expectEqualStrings("TypeError", outcome);
}

test "a page left with an XMLHttpRequest in flight is kept; nothing of it runs while cached, and it fails as a network error once shown again (Safari)" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/xhr.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "go(); 'started'", "started");
    try fixture.awaitRequests("/held.txt", 1);

    try fixture.goTo(bc, "location.href = '/b.html'", "/b.html");
    try testing.expectEqual(@as(usize, 1), fixture.cached());
    // The answer arrives while the page is cached: none of the request's
    // events may run in a page the cache keeps.
    fixture.server.release("/held.txt");
    try fixture.turn(200);
    try expectIn(realm_a, "outcome", "pending");

    try fixture.goTo(bc, "history.back()", "/xhr.html");
    try testing.expectEqual(realm_a, activeRealm(bc).?);
    try expectIn(realm_a, "log.join()", "pageshow:false,pagehide:true,pageshow:true");
    // Cancelled when the page was stored, the request fails once the page is
    // shown again as a network error does: readyState DONE, then error and
    // loadend (WebKit XMLHttpRequest::suspend for the back/forward cache, then
    // resumeTimerFired -> networkError).
    const outcome = try fixture.awaitOutcome(realm_a);
    defer testing.allocator.free(outcome);
    try testing.expectEqualStrings("error", outcome);
    try expectIn(realm_a, "events.slice(-3).join()", "readystatechange:4,error:4,loadend:4");
}

test "a navigation's start cancels the page's fetch, which rejects with a TypeError while the page is still shown (Firefox, Safari)" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/fetch.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "go(); 'started'", "started");
    try fixture.awaitRequests("/held.txt", 1);
    // A navigation away starts; its response is held, so it does not commit.
    try expectIn(realm_a, "location.href = '/held-nav.html'; 'navigating'", "navigating");
    // The fetch is cancelled as the navigation starts - a TypeError, as every
    // browser rejects a cancelled fetch - while the page is still shown.
    const outcome = try fixture.awaitOutcome(realm_a);
    defer testing.allocator.free(outcome);
    try testing.expectEqualStrings("TypeError", outcome);
    try expectIn(realm_a, "location.pathname", "/fetch.html");

    fixture.server.release("/held.txt");
    fixture.server.release("/held-nav.html");
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try popupIs(bc, "/held-nav.html")) break;
        try fixture.turn(10);
    }
}

test "window.stop() cancels the page's fetch, which rejects with a TypeError (Chrome, Firefox, Safari)" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    const bc = try fixture.openPopup("/fetch.html");
    const realm_a = activeRealm(bc).?;
    try expectIn(realm_a, "go(); 'started'", "started");
    try fixture.awaitRequests("/held.txt", 1);
    try expectIn(realm_a, "stop(); 'stopped'", "stopped");
    const outcome = try fixture.awaitOutcome(realm_a);
    defer testing.allocator.free(outcome);
    try testing.expectEqualStrings("TypeError", outcome);
    fixture.server.release("/held.txt");
    try fixture.turn(50);
}
