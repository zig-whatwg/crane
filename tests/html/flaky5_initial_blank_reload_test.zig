//! Lane flaky5: location.reload() of a frame's initial about:blank leaves the
//! frame's navigation in flight; a loaded document's reload ends it.
//!
//! html/semantics/embedded-content/the-iframe-element/
//! iframe-loading-lazy-reload-location-reload.html failed in generation 210's
//! sweep ("got about:blank"): Crane loads every iframe eagerly, so the test's
//! reload of the initial about:blank ran while the src navigation was in
//! flight, and the reload's population ended that navigation whenever the src
//! response had not arrived yet. HTML "attempt to populate the history entry's
//! document" step 5.1 abandons the reload instead, and Chrome 156, Firefox 159
//! and Safari 27 agree for the initial about:blank (lane flaky5's probe); for
//! a loaded document all three end the navigation in flight (the second
//! test). The server holds the frame's response until the reload has had its
//! turns, so the order is forced, not raced.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const page_url = "http://flaky5reload.test/page.html";

const routes = [_]http.Route{
    .{ .path = "/page.html", .content_type = "text/html", .body = "<!doctype html><body></body>" },
    .{ .path = "/first.html", .content_type = "text/html", .body = "<!doctype html><title>first</title>" },
    .{ .path = "/held.html", .content_type = "text/html", .body = "<!doctype html><title>held</title>", .held = true },
};

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

fn run(browser: *Browser, script: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(script);
}

/// Turn the event loop until `script` answers "true", or fail.
fn waitFor(browser: *Browser, script: []const u8) !void {
    var turns: usize = 0;
    while (turns < 400) : (turns += 1) {
        const now = try answer(browser, script);
        defer testing.allocator.free(now);
        if (std.mem.eql(u8, now, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.NeverHappened;
}

fn openPage(server: *http.Server) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigate(page_url, .window);
    try waitFor(browser, "document.readyState === 'complete'");
    return browser;
}

/// Let the reload's queued steps run while the held response is still out.
fn turns(browser: *Browser, n: usize) !void {
    for (0..n) |_| _ = try browser.runEventLoopBlocking(10);
}

test "location.reload() of a frame's initial about:blank does not end the frame's navigation in flight" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server);
    defer browser.deinit();
    try run(browser,
        \\globalThis.loads = [];
        \\globalThis.frame = document.createElement('iframe');
        \\frame.onload = () => loads.push(frame.contentWindow.location.href);
        \\frame.src = '/held.html';
        \\document.body.appendChild(frame);
        \\globalThis.before = frame.contentWindow.location.href;
        \\frame.contentWindow.location.reload();
    );
    var waited: usize = 0;
    while (server.count("/held.html") == 0 and waited < 200) : (waited += 1) _ = try browser.runEventLoopBlocking(10);
    try turns(browser, 30);
    server.release("/held.html");
    try waitFor(browser, "loads.length > 0");
    try turns(browser, 10);
    const result = try answer(browser, "before + ' | ' + frame.contentWindow.location.href + ' | ' + loads.join()");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("about:blank | http://flaky5reload.test/held.html | http://flaky5reload.test/held.html", result);
}

test "location.reload() of a loaded document ends the frame's navigation in flight, as Chrome, Firefox and Safari do" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server);
    defer browser.deinit();
    try run(browser,
        \\globalThis.loads = [];
        \\globalThis.frame = document.createElement('iframe');
        \\frame.onload = () => loads.push(frame.contentWindow.location.href);
        \\frame.src = '/first.html';
        \\document.body.appendChild(frame);
    );
    try waitFor(browser, "loads.length === 1");
    try turns(browser, 2);
    try run(browser,
        \\frame.contentWindow.location.href = '/held.html';
        \\frame.contentWindow.location.reload();
    );
    try waitFor(browser, "loads.length === 2");
    server.release("/held.html");
    try turns(browser, 30);
    const result = try answer(browser, "frame.contentWindow.location.href + ' | ' + loads.join()");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("http://flaky5reload.test/first.html | http://flaky5reload.test/first.html,http://flaky5reload.test/first.html", result);
}
