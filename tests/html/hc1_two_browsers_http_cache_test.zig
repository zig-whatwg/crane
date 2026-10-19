//! Two Browsers on two threads fetch the same URLs (lane httpcache1): each
//! has an HTTP cache of its own (docs/instances.md: the Browser owns "the
//! HTTP cache and network"), so each asks the server once and answers its
//! second fetch from its own cache - never from the other's. And within one
//! Browser, a page and its dedicated worker (on a thread of its own) share
//! the page's partition: the worker's fetch is a hit.
//!
//! Each Browser allocates from a DebugAllocator of its own (AGENTS.md: a
//! shared std.testing.allocator makes two Browsers take turns), which still
//! fails the test on a leak - the cache's included.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("hc1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/shared.txt", .body = "shared" },
    .{ .path = "/validated.txt", .body = "validated", .cache_control = "max-age=0", .etag = "\"v1\"" },
    .{ .path = "/worker.txt", .body = "from the page" },
    .{ .path = "/frame.html", .body = "<!doctype html><p>frame", .content_type = "text/html" },
    .{ .path = "/popup.html", .body = "<!doctype html><p>popup", .content_type = "text/html" },
};

const page_url = "http://hc1.test/page.html";

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

fn waitForAnswer(browser: *Browser) ![]u8 {
    for (0..1000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

/// Run `body` (an async function's body, its result a string) in the page.
fn runInPage(browser: *Browser, comptime body: []const u8) ![]u8 {
    const launch = "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + e; }); 'ok'";
    const started = try evaluate(browser, launch);
    browser.allocator.free(started);
    return waitForAnswer(browser);
}

fn startBrowser(allocator: std.mem.Allocator, server: *http.Server) !*Browser {
    return startBrowserWith(allocator, server, .{});
}

fn startBrowserWith(allocator: std.mem.Allocator, server: *http.Server, cache: @import("browser").BrowserConfig.HttpCacheConfig) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        .http_cache = cache,
    });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    return browser;
}

const fetch_twice =
    \\const a = await (await fetch('/shared.txt')).text();
    \\const b = await (await fetch('/shared.txt')).text();
    \\const v1 = await (await fetch('/validated.txt')).text();
    \\const v2 = await (await fetch('/validated.txt')).text();
    \\return [a, b, v1, v2].join(',');
;

const Side = struct {
    server: *http.Server,
    failure: ?anyerror = null,
    answer: [64]u8 = undefined,
    answer_len: usize = 0,

    fn main(self: *Side) void {
        self.run() catch |err| {
            self.failure = err;
        };
    }

    fn run(self: *Side) !void {
        var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug.deinit() != .ok) {
            self.failure = error.Leaked;
        };
        const browser = try startBrowser(debug.allocator(), self.server);
        defer browser.deinit();
        const got = try runInPage(browser, fetch_twice);
        defer browser.allocator.free(got);
        @memcpy(self.answer[0..got.len], got);
        self.answer_len = got.len;
    }
};

test "hc1 two Browsers: each answers its second fetch from its own HTTP cache, never the other's" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var a: Side = .{ .server = server };
    var b: Side = .{ .server = server };
    const ta = try std.Thread.spawn(.{}, Side.main, .{&a});
    const tb = try std.Thread.spawn(.{}, Side.main, .{&b});
    ta.join();
    tb.join();
    if (a.failure) |err| return err;
    if (b.failure) |err| return err;
    try std.testing.expectEqualStrings("shared,shared,validated,validated", a.answer[0..a.answer_len]);
    try std.testing.expectEqualStrings("shared,shared,validated,validated", b.answer[0..b.answer_len]);
    // One request per Browser for the fresh response: each second fetch was
    // its own cache's, and neither Browser saw the other's entry.
    try std.testing.expectEqual(@as(u32, 2), server.count("/shared.txt"));
    // The always-stale one: each second fetch revalidated (a 304) in its own
    // Browser - 2 Browsers x (200 + 304).
    try std.testing.expectEqual(@as(u32, 4), server.count("/validated.txt"));
    try std.testing.expectEqual(@as(u32, 2), server.notModified("/validated.txt"));
}

test "hc1 one Browser: a dedicated worker's fetch is answered from what its page stored" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(debug.deinit() == .ok) catch @panic("leaked");
    const browser = try startBrowser(debug.allocator(), server);
    defer browser.deinit();
    const got = try runInPage(browser,
        \\const page = await (await fetch('/worker.txt')).text();
        \\const source = `onmessage = async () => {
        \\  const r = await fetch('http://hc1.test/worker.txt');
        \\  postMessage(await r.text());
        \\};`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
        \\const fromWorker = await new Promise((resolve, reject) => {
        \\  worker.onmessage = e => resolve(e.data);
        \\  worker.onerror = () => reject('worker error');
        \\  worker.postMessage('go');
        \\});
        \\worker.terminate();
        \\return page + '|' + fromWorker;
    );
    defer browser.allocator.free(got);
    try std.testing.expectEqualStrings("from the page|from the page", got);
    // The worker's fetch never reached the server.
    try std.testing.expectEqual(@as(u32, 1), server.count("/worker.txt"));
}

const load_frame_twice =
    \\const loadFrame = () => new Promise(resolve => {
    \\  const f = document.createElement('iframe');
    \\  f.onload = () => { const text = f.contentDocument.body.textContent; f.remove(); resolve(text); };
    \\  f.src = '/frame.html';
    \\  document.body.append(f);
    \\});
    \\return [await loadFrame(), await loadFrame()].join(',');
;

const open_popup_twice =
    \\const loadPopup = async () => {
    \\  const w = window.open('/popup.html');
    \\  for (let i = 0; i < 500; ++i) {
    \\    await new Promise(r => setTimeout(r, 10));
    \\    if (w.document && w.document.readyState === 'complete' && w.location.pathname === '/popup.html') break;
    \\  }
    \\  const text = w.document.body.textContent;
    \\  w.close();
    \\  return text;
    \\};
    \\return [await loadPopup(), await loadPopup()].join(',');
;

/// Navigate twice in one Browser (with an HTTP cache of `max_bytes`) and
/// answer how many requests the server saw for `path`.
fn navigateTwice(comptime source: []const u8, path: []const u8, want: []const u8, max_bytes: usize) !u32 {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(debug.deinit() == .ok) catch @panic("leaked");
    const browser = try startBrowserWith(debug.allocator(), server, .{ .max_bytes = max_bytes });
    defer browser.deinit();
    const got = try runInPage(browser, source);
    defer browser.allocator.free(got);
    try std.testing.expectEqualStrings(want, got);
    return server.count(path);
}

test "hc1 one Browser: a frame navigation is stored and answered from the HTTP cache" {
    // A frame's request is keyed by its container's top-level site.
    try std.testing.expectEqual(@as(u32, 1), try navigateTwice(load_frame_twice, "/frame.html", "frame,frame", 50 * 1024 * 1024));
}

test "hc1 one Browser: without an HTTP cache, both frame navigations reach the server" {
    try std.testing.expectEqual(@as(u32, 2), try navigateTwice(load_frame_twice, "/frame.html", "frame,frame", 0));
}

test "hc1 one Browser: a popup navigation is stored and answered from the HTTP cache" {
    // A top-level traversable's request is keyed by its URL's site.
    try std.testing.expectEqual(@as(u32, 1), try navigateTwice(open_popup_twice, "/popup.html", "popup,popup", 50 * 1024 * 1024));
}

test "hc1 one Browser: without an HTTP cache, both popup navigations reach the server" {
    try std.testing.expectEqual(@as(u32, 2), try navigateTwice(open_popup_twice, "/popup.html", "popup,popup", 0));
}
