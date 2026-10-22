//! A navigation in flight in a frame INSIDE a removed frame ends with it.
//!
//! HTML "destroy a child navigable" destroys the removed frame's document and
//! its descendants; Blink stops every one of their loads as it detaches them
//! (LocalFrame::DetachImpl: loader_.StopAllLoaders(), then DetachChildren(),
//! which detaches each child frame the same way). Crane ended the removed
//! frame's own navigations (IFrameIntegration.onRemovedFromDocument) but not
//! its descendants': a navigation started in the inner frame committed after
//! the outer frame was gone - a new document made, and its script run, in a
//! navigable already destroyed, and a service worker client made for a realm
//! whose unloading cleanup had already run, which nothing ever ended (lane
//! exitleak1: 5 leaked blocks at the WPT runner's exit after
//! html/browsers/browsing-the-web/unloading-documents/navigation-during-beforeunload.html,
//! subtest 3).
//!
//! The inner page comes from a loopback HTTP server (module1_http_server.zig)
//! through the Browser's proxy, answering late, so that - as in the WPT file
//! - the response arrives after the removed frame's realm-end task has run.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const host_url = "http://exitleak1.test/host.html";

const routes = [_]http.Route{
    .{ .path = "/late.html", .content_type = "text/html", .body = "<!doctype html><p>late<script>var ran = true;</script>", .delay_ms = 200 },
};

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

test "removing a frame ends the navigation in flight in the frame inside it: nothing it would commit is left behind" {
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
        \\  var outer = document.createElement('iframe');
        \\  document.body.append(outer);
        \\  var inner = outer.contentDocument.createElement('iframe');
        \\  outer.contentDocument.body.append(inner);
        \\</script>
    , .{ .base_url = host_url });
    _ = try browser.runEventLoopBlocking(20);
    {
        const before = try answer(browser, "inner.contentDocument ? inner.contentDocument.URL : 'none'");
        defer testing.allocator.free(before);
        try testing.expectEqualStrings("about:blank", before);
    }
    // The inner frame's navigation starts; its container's container goes
    // before the response arrives.
    try page.runScript("inner.src = '/late.html'; outer.remove();");
    var turns: usize = 0;
    while (turns < 100 and server.count("/late.html") == 0) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
    try testing.expectEqual(@as(u32, 1), server.count("/late.html"));
    // Time for the response to arrive and, before the fix, to commit: the
    // committed document's service worker client is what testing.allocator
    // reports when the Browser ends (5 blocks: the client, its origin,
    // storage key and creation URL, and the task sink it retains).
    turns = 0;
    while (turns < 40) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
}
