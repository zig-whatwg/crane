//! A declarative refresh to the document's own URL is a reload, and the
//! reload aborts the document's fetches once it begins.
//!
//! HTML's "shared declarative refresh steps" navigate (step 13), and navigate
//! step 24.3 aborts the active document and its descendants as soon as
//! beforeunload lets the navigation go on - before the replacement is
//! fetched. Crane reloads instead, as all three browsers do for a refresh to
//! the same URL (Document.refreshComesDue); its "apply the reload history
//! step" kept no abort, so a fetch the refreshing document had started raced
//! the reload's response: html/webappapis/dynamic-markup-insertion/
//! opening-the-input-stream/abort-refresh-immediate.window.js's fetch()
//! cases failed whenever the fetch's answer came first (flaky3). Firefox and
//! Safari stop the old document's loads when the reload begins
//! (nsDocShell::InternalLoad's StopInternal(STOP_NETWORK),
//! FrameLoader::continueLoadAfterNavigationPolicy's stopAllLoaders).
//!
//! The interleaving is forced by the loopback server: the fetch is answered
//! after 300 ms, the reloaded document after 1,500 ms. Without the abort the
//! fetch resolves first, every run.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const host_url = "http://fl3refresh.test/host.html";

const routes = [_]http.Route{
    .{ .path = "/frame.html", .content_type = "text/html", .body = "<!doctype html><meta http-equiv=refresh content=0><p>refreshing", .delay_ms = 1500 },
    .{ .path = "/slow.txt", .content_type = "text/plain", .body = "late", .delay_ms = 300 },
};

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

test "a refresh's reload aborts the fetch its document started, before the reloaded document arrives" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body><script>
        \\  var result = 'pending';
        \\  var frame = document.createElement('iframe');
        \\  frame.onload = () => {
        \\    frame.onload = null;
        \\    frame.contentWindow.fetch('/slow.txt').then(() => { result = 'resolved'; }, () => { result = 'rejected'; });
        \\  };
        \\  frame.src = '/frame.html';
        \\  document.body.append(frame);
        \\</script>
    , .{ .base_url = host_url });
    var turns: usize = 0;
    while (turns < 400) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(10);
        const now = try answer(browser, "result");
        defer testing.allocator.free(now);
        if (!std.mem.eql(u8, now, "pending")) break;
    }
    const result = try answer(browser, "result");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("rejected", result);
    // The fetch went out, and so did the reload: the refresh came due.
    try testing.expectEqual(@as(u32, 1), server.count("/slow.txt"));
    turns = 0;
    while (turns < 100 and server.count("/frame.html") < 2) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
    try testing.expectEqual(@as(u32, 2), server.count("/frame.html"));
}
