//! XML SVG and XHTML scripts share the embedder's parser loader. A null
//! answer and scripts inserted by script still use the ordinary fetch path.
//! The loader is the Browser's registration (html.embedder_scripts), which
//! answers for every document the Browser parses - the one embedder hook
//! left, for the WPT runner's testdriver vendor file until test_driver's
//! commands move into src/webdriver (lane wptcfg; the navigation's own
//! loader is gone, the user, 2026-11-09).
const std = @import("std");
const browser_mod = @import("browser");
const html = @import("html");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Loader = struct {
    calls: usize = 0,
    nested_calls: usize = 0,

    /// The loader in use: the test's (it runs on the test's own thread,
    /// helpers.onFreshThread), set for the test's length.
    var current: ?*Loader = null;

    fn load(realm: runtime.Context, url: []const u8) ?[]const u8 {
        const self = current orelse return null;
        if (std.mem.indexOf(u8, url, "xm1Nested") != null) self.nested_calls += 1;
        if (!std.mem.startsWith(u8, url, "https://xm1.invalid/")) return null;
        self.calls += 1;
        // embedder_scripts.Loader: allocated with the realm's allocator.
        return realm.allocator.dupe(u8, "globalThis.xm1Loaded = (globalThis.xm1Loaded || 0) + 1;") catch null;
    }
};

fn loadMarkup(browser: *browser_mod.Browser, loader: *Loader, mime: []const u8, source: []const u8) !void {
    const encoder = std.base64.standard.Encoder;
    const encoded = try std.testing.allocator.alloc(u8, encoder.calcSize(source.len));
    defer std.testing.allocator.free(encoded);
    _ = encoder.encode(encoded, source);
    const url = try std.fmt.allocPrint(std.testing.allocator, "data:{s};base64,{s}", .{ mime, encoded });
    defer std.testing.allocator.free(url);
    _ = loader;
    try browser.navigate(url, .window);
}

fn scriptLoaders() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var loader: Loader = .{};
    Loader.current = &loader;
    defer Loader.current = null;
    try html.embedder_scripts.register(browser.scope, &Loader.load);
    defer html.embedder_scripts.unregister(browser.scope);
    try loadMarkup(browser, &loader, "text/html",
        \\<!doctype html><script src="https://xm1.invalid/html.js"></script>
        \\<script src="data:text/javascript,globalThis.xm1Fallback=1"></script>
    );
    _ = try browser.runEventLoopBlocking(200);
    try std.testing.expectEqual(@as(usize, 1), loader.calls);
    const html_result = try browser.current_context.?.evaluateScriptToString("xm1Loaded + ':' + xm1Fallback", std.testing.allocator);
    defer std.testing.allocator.free(html_result);
    try std.testing.expectEqualStrings("1:1", html_result);

    loader.calls = 0;
    try loadMarkup(browser, &loader, "image/svg+xml",
        \\<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink">
        \\<h:script src="https://xm1.invalid/xhtml.js"/>
        \\<script href="https://xm1.invalid/svg.js"/>
        \\<script xlink:href="https://xm1.invalid/xlink.js"/>
        \\<script href="data:text/javascript,globalThis.xm1Fallback=1"/>
        \\<script><![CDATA[
        \\const inserted = document.createElementNS('http://www.w3.org/2000/svg', 'script');
        \\inserted.setAttribute('href', 'data:text/javascript,globalThis.xm1Nested=1');
        \\document.documentElement.appendChild(inserted);
        \\]]></script>
        \\</svg>
    );
    _ = try browser.runEventLoopBlocking(20);
    try std.testing.expectEqual(@as(usize, 3), loader.calls);
    try std.testing.expectEqual(@as(usize, 0), loader.nested_calls);
    const svg_result = try browser.current_context.?.evaluateScriptToString("xm1Loaded + ':' + xm1Fallback + ':' + xm1Nested", std.testing.allocator);
    defer std.testing.allocator.free(svg_result);
    try std.testing.expectEqualStrings("3:1:1", svg_result);
}

test "XML SVG parser scripts use their loader, with HTML and network fallbacks preserved" {
    try helpers.onFreshThread(scriptLoaders);
}
