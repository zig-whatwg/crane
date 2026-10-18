//! HTML "update the image data" step 26: "When delay load event is true,
//! fetching the image must delay the load event of element's node document
//! until the task that is queued by the networking task source once the
//! resource has been fetched has been run" - and step 24 makes `delay load
//! event` true only for an img whose loading attribute is in the Eager
//! state. So an eager img's load (or error) event fires before its
//! document's load event, and a lazy one's after it when its response is
//! slower (Crane loads a lazy img at once: it has no viewport).
//!
//! Each page records the order of its events in `order`. The image is served
//! 300 ms late, and is no image at all, so its event is `error` - which
//! delays the load event as `load` does.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/slow.png", .content_type = "image/png", .delay_ms = 300, .body = "not a png" },
};

const page_url = "http://imgdelay.test/page.html";

fn page(comptime loading: []const u8) []const u8 {
    return "<!doctype html><script>var order = []; addEventListener('load', () => order.push('window'));</script>" ++
        "<img " ++ loading ++ " src='/slow.png' onload=\"order.push('img')\" onerror=\"order.push('img')\">";
}

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const current = browser.current_context orelse return error.NoPage;
    return current.evaluateScriptToString(source, browser.allocator);
}

/// The page's events, once both have fired.
fn orderOf(browser: *Browser) ![]u8 {
    for (0..300) |_| {
        const order = try evaluate(browser, "order.length >= 2 ? order.join(',') : 'pending'");
        if (!std.mem.eql(u8, order, "pending")) return order;
        browser.allocator.free(order);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn expectOrder(comptime loading: []const u8, want: []const u8) !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(std.testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const current = browser.current_context orelse return error.NoPage;
    try current.loadHTML(page(loading), .{ .base_url = page_url });
    const order = try orderOf(browser);
    defer browser.allocator.free(order);
    try std.testing.expectEqualStrings(want, order);
}

test "an eager img delays its document's load event until its event has fired" {
    try expectOrder("", "img,window");
    try expectOrder("loading=eager", "img,window");
    // An invalid value is the Eager state (the missing value default).
    try expectOrder("loading=bogus", "img,window");
}

test "a lazy img does not delay its document's load event" {
    try expectOrder("loading=lazy", "window,img");
}
