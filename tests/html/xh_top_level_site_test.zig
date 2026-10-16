//! Fetch "determine the network partition key": a request's client carries
//! its environment's top-level site (HTML "obtain a site" of the top-level
//! origin), which keys the per-Browser CORS-preflight cache and authentication
//! entries (Codex row 44, ANSWER Q4). A Window's is its top-level window's
//! origin's site; a frame's is its top's, not its own; an opaque top-level
//! origin has none, and a request without one bypasses those stores.
//!
//! Before, nothing filled `RequestClient.top_level_site`, so every request's
//! key was null and both stores were bypassed for every request.

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const dom = @import("dom");

fn siteOfPage(html: []const u8, url: []const u8, frame_script: ?[]const u8) !?[]u8 {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = url });
    _ = try browser.runEventLoopBlocking(50);
    const window = page.window_instance orelse return error.NoWindow;
    const global = if (frame_script) |script| blk: {
        // The frame's window, as script reaches it.
        const result = try page.evaluateScriptToString(script, testing.allocator);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("ok", result);
        const context = dom.browser_state.browsingContextOf(window) orelse return error.NoContext;
        if (context.children.items.len == 0) return error.NoFrames;
        const frame = context.children.items[0].getActiveWindow() orelse return error.NoFrameWindow;
        break :blk @as(*@import("runtime").Instance, @ptrCast(@alignCast(frame)));
    } else window;
    var client = try dom.global_settings.requestClient(global);
    defer client.deinit();
    const site = client.request.top_level_site orelse return null;
    return try testing.allocator.dupe(u8, site);
}

test "a top-level window's requests carry its origin's site, not its origin" {
    const site = (try siteOfPage("<!doctype html><body>", "http://sub.inst.test:8000/p.html", null)) orelse return error.NoSite;
    defer testing.allocator.free(site);
    try testing.expectEqualStrings("http://inst.test", site);
}

test "an opaque top-level origin has no site: its requests carry none" {
    try testing.expectEqual(@as(?[]u8, null), try siteOfPage("<!doctype html><body>", "data:text/html,x", null));
}

test "a frame's requests carry its top-level window's site" {
    const site = (try siteOfPage(
        "<!doctype html><body><iframe></iframe>",
        "http://www.top.test:8000/p.html",
        "frames.length === 1 ? 'ok' : 'no frame'",
    )) orelse return error.NoSite;
    defer testing.allocator.free(site);
    try testing.expectEqualStrings("http://top.test", site);
}
