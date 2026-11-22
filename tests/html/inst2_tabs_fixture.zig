//! Lane inst2's fixture: a Browser whose tabs are its top-level traversables
//! - the host's page, and the popups its script opens (docs/instances.md:
//! "every popup is a tab, noopener included", as WebDriver BiDi reports
//! them) - over a loopback HTTP server reached through the Browser's
//! manual proxy (module1_http_server.zig), so every page is a real
//! http://localhost document: one origin, and a secure context (HTML
//! "potentially trustworthy origin": localhost), which Web Locks, the
//! Cookie Store API and service workers need.
//!
//! A tab is named by its top-level browsing context, found through the
//! Browser's navigables; script runs in a tab's active realm.
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

pub const Browser = browser_mod.Browser;
pub const BrowsingContext = html.BrowsingContext;

pub const origin = "http://localhost";
pub const host_url = origin ++ "/host.html";

/// Every page logs what reaches it: its storage events, its
/// BroadcastChannel "c" messages and its cookie changes.
pub const page_script =
    \\var storageEvents = [];
    \\addEventListener('storage', e => storageEvents.push([e.key, e.oldValue, e.newValue, e.url, e.storageArea === localStorage ? 'local' : e.storageArea === sessionStorage ? 'session' : 'other'].join('|')));
    \\var messages = [];
    \\var channel = new BroadcastChannel('c');
    \\channel.onmessage = e => messages.push(String(e.data));
;

pub const page_html = "<!doctype html><title>tab</title><script>" ++ page_script ++ "</script>";

pub const routes = [_]http.Route{
    .{ .path = "/page.html", .content_type = "text/html", .body = page_html },
    .{ .path = "/other.html", .content_type = "text/html", .body = page_html },
    // A shared worker that counts the connections it gets.
    .{ .path = "/counter.js", .body = "let n = 0; onconnect = e => { e.ports[0].postMessage(++n); };" },
    // A service worker that does nothing.
    .{ .path = "/sw.js", .body = "self.addEventListener('install', () => {});" },
};

pub const Fixture = struct {
    allocator: std.mem.Allocator,
    server: *http.Server,
    browser: *Browser,
    proxy_buf: [64]u8 = undefined,

    /// A Browser showing `host_url`, its first tab. `allocator` is the
    /// Browser's and the server's (a thread's own, for two Browsers).
    pub fn start(allocator: std.mem.Allocator) !*Fixture {
        const self = try allocator.create(Fixture);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.server = try http.Server.start(allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        self.browser = try Browser.init(allocator, .{
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        errdefer self.browser.deinit();
        try self.showHostPage(host_url);
        return self;
    }

    pub fn stop(self: *Fixture) void {
        self.browser.deinit();
        self.server.stop();
        self.allocator.destroy(self);
    }

    /// The host's page: a FRESH top-level traversable at `url`, the page
    /// before it closed (Browser.navigate), its markup given here.
    pub fn showHostPage(self: *Fixture, url: []const u8) !void {
        try self.browser.navigateWithOptions(url, .window, .{ .skip_load = true });
        const context = self.browser.current_context orelse return error.NoPage;
        try context.loadHTML(page_html, .{ .base_url = url });
    }

    pub fn turn(self: *Fixture, ms: u64) !void {
        _ = try self.browser.runEventLoopBlocking(ms);
    }

    /// The host page's tab.
    pub fn hostTab(self: *Fixture) !*BrowsingContext {
        const window = hostWindow(self.browser) orelse return error.NoPage;
        return dom.browser_state.browsingContextOf(window) orelse error.NoPage;
    }

    /// The open tabs, host's first (Browser.traversableIds).
    pub fn tabCount(self: *Fixture) usize {
        var ids: [16]u64 = undefined;
        return self.browser.traversableIds(&ids);
    }

    /// The open tab with this id.
    pub fn tab(self: *Fixture, id: u64) ?*BrowsingContext {
        const navigables = dom.browser_state.existingNavigablesIn(self.browser.scope) orelse return null;
        const bc = navigables.byId(id) orelse return null;
        if (bc.parent != null or bc.is_closed or bc.orphaned) return null;
        return bc;
    }

    /// Run `source` in the host page and wait until a NEW tab shows a
    /// loaded document at `path`: that tab. `source` opens it
    /// (window.open, with or without noopener).
    pub fn openTab(self: *Fixture, source: []const u8, comptime path: []const u8) !*BrowsingContext {
        var before: [16]u64 = undefined;
        const count_before = self.browser.traversableIds(&before);
        const host = try self.hostTab();
        try self.run(host, source);
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            var now: [16]u64 = undefined;
            const count = self.browser.traversableIds(&now);
            for (now[0..@min(count, now.len)]) |id| {
                if (std.mem.indexOfScalar(u64, before[0..@min(count_before, before.len)], id) != null) continue;
                const bc = self.tab(id) orelse continue;
                if (try self.shows(bc, path)) {
                    // Its load's own tasks run first.
                    try self.turn(20);
                    return bc;
                }
            }
            try self.turn(10);
        }
        return error.TimedOut;
    }

    /// Whether tab `bc` shows a loaded document at `path`.
    pub fn shows(self: *Fixture, bc: *BrowsingContext, comptime path: []const u8) !bool {
        _ = self;
        const realm = activeRealm(bc) orelse return false;
        return isTrue(realm, "document.readyState === 'complete' && location.pathname === '" ++ path ++ "'");
    }

    /// Run `source` in tab `bc`'s active window.
    pub fn run(self: *Fixture, bc: *BrowsingContext, source: []const u8) !void {
        _ = self;
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const answer = try evaluateIn(realm, source);
        testing.allocator.free(answer);
    }

    /// `source` in tab `bc`'s active window, ToString'd, is `expected`.
    pub fn expect(self: *Fixture, bc: *BrowsingContext, source: []const u8, expected: []const u8) !void {
        _ = self;
        const realm = activeRealm(bc) orelse return error.NoRealm;
        const answer = try evaluateIn(realm, source);
        defer testing.allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, answer });
        try testing.expectEqualStrings(expected, answer);
    }

    /// Turn the loop until `source`, in tab `bc`, answers true.
    pub fn waitFor(self: *Fixture, bc: *BrowsingContext, source: []const u8) !void {
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            const realm = activeRealm(bc) orelse return error.NoRealm;
            if (try isTrue(realm, source)) return;
            try self.turn(10);
        }
        std.debug.print("never true: {s}\n", .{source});
        return error.TimedOut;
    }

    /// Turn the loop until the tab with this id is no tab: closed, and its
    /// browsing context freed - every Window that showed it has ended.
    pub fn waitUntilGone(self: *Fixture, id: u64) !void {
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            const navigables = dom.browser_state.existingNavigablesIn(self.browser.scope) orelse return;
            if (navigables.byId(id) == null) return;
            try self.turn(10);
            if (turns % 20 == 19) try self.collect();
        }
        return error.TimedOut;
    }

    /// Collect in the host page, and let what the collection queued run.
    pub fn collect(self: *Fixture) !void {
        const host = try self.hostTab();
        try self.run(host, "TestUtils.gc(); TestUtils.gc();");
        try self.turn(20);
    }
};

pub fn hostWindow(browser: *Browser) ?*runtime.Instance {
    const realm = browser.getRealm() orelse return null;
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

pub fn activeRealm(bc: *BrowsingContext) ?runtime.Context {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return null));
    return window.ctx;
}

fn logReporter(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("uncaught: {s}\n", .{info.message});
}

/// `source` evaluated in `realm`, ToString'd: owned by testing.allocator.
pub fn evaluateIn(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
}

pub fn isTrue(realm: runtime.Context, source: []const u8) !bool {
    const answer = try evaluateIn(realm, source);
    defer testing.allocator.free(answer);
    return std.mem.eql(u8, answer, "true");
}
