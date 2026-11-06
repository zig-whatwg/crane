//! A frame's navigations in flight are their Browser's
//! (`Navigables.navigations`, lane gstate4), and whoever keeps only a
//! navigation's ID - an event-loop task, the navigation fetch's client, a
//! streamed body's holder - keeps it in a ticket with that list, freed
//! exactly once by the holder's end. They were one map per thread
//! (HTMLIFrameElement `navigations`).
//!
//! std.testing.allocator (and, across two threads, a DebugAllocator per
//! Browser) fails a test on a ticket never freed or freed twice; each test
//! takes its tickets down one path: a task run, a task dropped unrun with
//! its loop, the fetch's end, the fetch terminated with its navigation, a
//! navigation ended while its task waited.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const routes = [_]http.Route{
    .{ .path = "/page.html", .content_type = "text/html", .body = "<!doctype html><p id=p>page</p>" },
    .{ .path = "/held.html", .content_type = "text/html", .body = "<!doctype html><p id=p>held</p>", .held = true },
    .{ .path = "/held2.html", .content_type = "text/html", .body = "<!doctype html><p id=p>held2</p>", .held = true },
};

fn startBrowser(allocator: std.mem.Allocator, server: *http.Server) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    return Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
}

fn truthy(browser: *Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn run(browser: *Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn waitFor(browser: *Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

fn turnLoop(browser: *Browser, n: usize) !void {
    for (0..n) |_| _ = try browser.runEventLoopBlocking(10);
}

/// A page with `frames` empty iframes, `f0`, `f1`...
fn openPage(browser: *Browser, url: []const u8, frames: usize) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    var buffer: [256]u8 = undefined;
    try run(browser, try std.fmt.bufPrint(&buffer, "for (let i = 0; i < {d}; i++) {{ const f = document.createElement('iframe'); f.id = 'f' + i; document.body.append(f); }}", .{frames}));
    try turnLoop(browser, 2);
}

/// The navigations in flight on `browser`'s list.
fn inFlight(browser: *Browser) usize {
    const list = dom.browser_state.existingNavigablesIn(browser.scope) orelse return 0;
    return list.navigations.count();
}

fn waitForRequests(browser: *Browser, server: *http.Server, path: []const u8, n: u32) !void {
    var t: usize = 0;
    while (t < 300 and server.count(path) < n) : (t += 1) _ = try browser.runEventLoopBlocking(10);
    try testing.expect(server.count(path) >= n);
}

test "a frame navigation's fetch ends, its commit task runs: every ticket goes once" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(testing.allocator, server);
    defer browser.deinit();
    try openPage(browser, "http://gs4.test/host.html", 1);
    try run(browser, "f0.src = '/page.html'");
    try waitFor(browser, "f0.contentDocument && f0.contentDocument.getElementById('p') && f0.contentDocument.getElementById('p').textContent === 'page'");
    try testing.expectEqual(@as(usize, 0), inFlight(browser));
}

test "a frame removed with its fetch in flight ends its navigation, and the fetch's ticket with it" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(testing.allocator, server);
    defer browser.deinit();
    try openPage(browser, "http://gs4.test/host.html", 1);
    const before = server.count("/held.html");
    try run(browser, "f0.src = '/held.html'");
    try waitForRequests(browser, server, "/held.html", before + 1);
    try testing.expectEqual(@as(usize, 1), inFlight(browser));
    try run(browser, "f0.remove()");
    try turnLoop(browser, 3);
    try testing.expectEqual(@as(usize, 0), inFlight(browser));
    server.release("/held.html");
    try turnLoop(browser, 10);
}

test "a navigation ended while its task waited is not found when the task runs" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(testing.allocator, server);
    defer browser.deinit();
    try openPage(browser, "http://gs4.test/host.html", 1);
    // A javascript: URL runs in a task; the navigation after it replaces it
    // as the frame's ongoing navigation before the task runs, ending it.
    try run(browser, "f0.src = 'javascript:\"<p id=p>js</p>\"'; f0.src = '/page.html'");
    try waitFor(browser, "f0.contentDocument && f0.contentDocument.getElementById('p') && f0.contentDocument.getElementById('p').textContent === 'page'");
    try testing.expectEqual(@as(usize, 0), inFlight(browser));
}

test "a Browser that ends with a navigation's task still queued drops the task, and its ticket" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(testing.allocator, server);
    try openPage(browser, "http://gs4.test/host.html", 1);
    try run(browser, "f0.src = 'javascript:\"<p>never</p>\"'");
    // No turn of the loop: the task is still queued when the Browser ends.
    browser.deinit();
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
    server: *http.Server,
    url: []const u8,
    path: []const u8,
    frames: usize,
    ends_first: bool,
    failure: ?anyerror = null,
    debug_allocator: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run_(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator(), self.server);
        var ended = false;
        defer if (!ended) browser.deinit();
        try openPage(browser, self.url, self.frames);
        var buffer: [160]u8 = undefined;
        try run(browser, try std.fmt.bufPrint(&buffer, "for (let i = 0; i < {d}; i++) document.getElementById('f' + i).src = '{s}';", .{ self.frames, self.path }));
        var t: usize = 0;
        while (t < 300 and inFlight(browser) < self.frames) : (t += 1) _ = try browser.runEventLoopBlocking(10);
        // Each Browser's list holds its own navigations in flight.
        try testing.expectEqual(self.frames, inFlight(browser));
        try self.shared.meet(1);
        try testing.expectEqual(self.frames, inFlight(browser));
        try self.shared.meet(2);
        // One Browser ends with its navigations in flight: its tickets go
        // (its allocator says so), and the other's list is untouched.
        if (self.ends_first) {
            browser.deinit();
            ended = true;
        }
        try self.shared.meet(3);
        if (!self.ends_first) {
            try testing.expectEqual(self.frames, inFlight(browser));
            self.server.release(self.path);
            try waitFor(browser, "[...document.querySelectorAll('iframe')].every((f) => f.contentDocument && f.contentDocument.getElementById('p'))");
            try testing.expectEqual(@as(usize, 0), inFlight(browser));
        }
    }
};

test "two Browsers on two threads each keep only their own navigations, and one's end with navigations in flight leaves the other's" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var shared: Shared = .{};
    var sides = [_]Side{
        .{ .shared = &shared, .server = server, .url = "http://gs4-a.test/host.html", .path = "/held.html", .frames = 2, .ends_first = true },
        .{ .shared = &shared, .server = server, .url = "http://gs4-b.test/host.html", .path = "/held2.html", .frames = 3, .ends_first = false },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run_, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
