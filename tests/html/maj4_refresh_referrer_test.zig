//! A declarative refresh to the document's own URL reloads it (Crane does as
//! all three browsers do: Document.refreshComesDue), and the reloaded
//! document's referrer is the document that refreshed, as for the navigation
//! the refresh steps make "using document" - not empty.
//! html/semantics/document-metadata/the-meta-element/pragma-directives/
//! attr-meta-http-equiv-refresh/parsing.html: "referrer is previous page" for
//! every refresh to the same URL, Chrome 157, Firefox 160 and Safari 27.2 at
//! wpt.fyi 2358bd4835. Blink's NavigationScheduler navigates with a
//! FrameLoadRequest whose origin document is the refreshing one (load type
//! reload for the same URL); Gecko's nsDocShell::ForceRefreshURI gives the
//! load the document's ReferrerInfo.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

/// The first load inserts a refresh meta (a meta in the markup would refresh
/// the reloaded document again); the reloaded one reports its referrer.
const refreshing_page =
    \\<!doctype html><script>
    \\  if (!name) { name = 'first'; const m = document.createElement('meta'); m.httpEquiv = 'refresh'; m.content = '0'; document.head.append(m); }
    \\  else if (name == 'first') { name = 'reloaded ' + document.referrer; if (parent != window) parent.result = name; }
    \\</script>
;

const routes = [_]http.Route{
    .{ .path = "/self.html", .content_type = "text/html", .body = refreshing_page },
    .{ .path = "/top.html", .content_type = "text/html", .body = "<!doctype html><script>globalThis.result = '';</script><iframe src=/frame.html></iframe>" },
    .{ .path = "/frame.html", .content_type = "text/html", .body = refreshing_page },
};

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

/// Runs the loop until `script` gives something starting with "reloaded",
/// then returns it.
fn waitFor(browser: *Browser, script: []const u8) ![]u8 {
    var turns: usize = 0;
    while (turns < 300) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(10);
        const now = try answer(browser, script);
        if (std.mem.startsWith(u8, now, "reloaded")) return now;
        testing.allocator.free(now);
    }
    return answer(browser, script);
}

/// `proxy_buf` holds the proxy URL for the Browser's life.
fn openBrowser(server: *http.Server, proxy_buf: *[64]u8) !*Browser {
    const proxy = try server.proxyUrl(proxy_buf);
    return Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
}

test "a page that refreshes to its own URL is reloaded with itself as the referrer" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const browser = try openBrowser(server, &proxy_buf);
    defer browser.deinit();
    try browser.navigate("http://maj4refresh.test/self.html", .window);
    const result = try waitFor(browser, "name");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("reloaded http://maj4refresh.test/self.html", result);
}

test "a frame that refreshes to its own URL is reloaded with itself as the referrer" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const browser = try openBrowser(server, &proxy_buf);
    defer browser.deinit();
    try browser.navigate("http://maj4refresh.test/top.html", .window);
    const result = try waitFor(browser, "result");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("reloaded http://maj4refresh.test/frame.html", result);
}
