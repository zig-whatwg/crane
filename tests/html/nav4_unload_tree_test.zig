//! "Unload a document and its descendants" in the browsers' order (lane
//! nav4): a document's pagehide and unload, then its child navigables'
//! documents' - while the document itself is still there. It is destroyed
//! (unload step 20, not salvageable) only once its descendants have
//! unloaded: Blink's FrameLoader::DetachDocument dispatches the document's
//! unload events, then LocalFrame::DetachChildren, and Document::Shutdown
//! comes after them.
//!
//! So a listener the parent page added to its iframe's window runs at the
//! child's unload - a function of the parent's realm, which is not gone yet -
//! and still reaches the frame through iframe.contentWindow: here it logs to
//! the opener and starts a keepalive fetch, as
//! fetch/api/redirect/redirect-keepalive.any.js does from a window it closes
//! (Chrome 157, Firefox 160 and Safari 27.2 pass all 12 subtests on wpt.fyi
//! stable at 2358bd4835).
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! the Browser's proxy. tests/html is one executable: the engine may already
//! be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const host_url = "http://nav4u.test/host.html";

/// A page with one iframe whose unload its own script listens for: the
/// listener, a function of this page's realm, logs to the opener whether the
/// frame's window is still reachable, then sends a keepalive fetch from it.
const top_page = "<!doctype html><title>top</title><iframe src=/frame.html></iframe><script>" ++
    "addEventListener('load', () => {" ++
    "  const f = document.querySelector('iframe');" ++
    "  f.contentWindow.addEventListener('unload', () => {" ++
    "    opener.log.push('child unload, frame window ' + (f.contentWindow !== null));" ++
    "    f.contentWindow.fetch('/hit', {keepalive: true});" ++
    "  });" ++
    "  opener.log.push('ready');" ++
    "});" ++
    "</script>";

const routes = [_]http.Route{
    .{ .path = "/top.html", .content_type = "text/html", .body = top_page },
    .{ .path = "/frame.html", .content_type = "text/html", .body = "<!doctype html><title>frame</title>" },
    .{ .path = "/b.html", .content_type = "text/html", .body = "<!doctype html><title>b</title>" },
    .{ .path = "/hit", .content_type = "text/plain", .body = "hit" },
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

    fn turn(self: *Fixture) !void {
        _ = try self.browser.runEventLoopBlocking(10);
    }

    fn hostIs(self: *Fixture, source: []const u8) !bool {
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        const answer = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
        defer testing.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }

    fn run(self: *Fixture, source: []const u8) !void {
        const ran = try self.browser.evaluateScript(source);
        ran.release();
    }

    /// Turn the event loop until `source`, evaluated in the host, is true.
    fn waitFor(self: *Fixture, source: []const u8) !void {
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (try self.hostIs(source)) return;
            try self.turn();
        }
        return error.TimedOut;
    }

    /// Turn the event loop until the server got `n` requests for `path`.
    fn waitForRequests(self: *Fixture, path: []const u8, n: u32) !void {
        var turns: usize = 0;
        while (turns < 500) : (turns += 1) {
            if (self.server.count(path) >= n) return;
            try self.turn();
        }
        return error.TimedOut;
    }

    /// Open /top.html as a popup the host can close, and wait until its
    /// listener is in place.
    fn openTop(self: *Fixture) !void {
        try self.run("var log = []; var w = window.open('http://nav4u.test/top.html');");
        try self.waitFor("log.join() === 'ready'");
    }
};

fn logReporter(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

test "a page's listener for its frame's unload runs when the opener closes the page, and reaches the frame" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    try fixture.openTop();

    try fixture.run("w.close();");
    try fixture.waitFor("w.closed && log.length > 1");
    try testing.expect(try fixture.hostIs("log.join() === 'ready,child unload, frame window true'"));
    // The frame's keepalive fetch outlives the page.
    try fixture.waitForRequests("/hit", 1);
}

test "a page's listener for its frame's unload runs when the page navigates away, and reaches the frame" {
    const fixture = try Fixture.start();
    defer fixture.stop();
    try fixture.openTop();

    try fixture.run("w.location.href = 'http://nav4u.test/b.html';");
    try fixture.waitFor("log.length > 1");
    try testing.expect(try fixture.hostIs("log.join() === 'ready,child unload, frame window true'"));
    try fixture.waitForRequests("/hit", 1);
    try fixture.waitFor("w.document.readyState === 'complete' && w.location.pathname === '/b.html'");
}
