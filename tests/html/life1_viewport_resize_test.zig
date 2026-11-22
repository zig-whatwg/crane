//! A top-level traversable's viewport is the host's to say (lane life1): the
//! platform's `window_rect_changed(tab, rect)` - a headless window's rect is
//! its viewport (the integrator's ruling C, 2026-11-21) - or a host's
//! override (src/browser/viewport.zig setOverride: CDP
//! Emulation.setDeviceMetricsOverride), which wins while set. innerWidth and
//! innerHeight read it, and so do the media queries; a change runs, at the
//! next rendering opportunity, the resize steps (HTML update the rendering
//! step 8: one `resize` at the Window when the size moved since the last
//! run) and the media query steps (step 10: a MediaQueryList's change).
const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const html = @import("html");
const browser_mod = @import("browser");

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Run the page's tasks until `condition` (a script) is true, bounded at 5 s.
fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

/// Post `window_rect_changed(tab, rect)` to `browser`, as a platform's
/// observer would: through the Browser's EventSink, on this thread.
fn postWindowRect(browser: *browser_mod.Browser, tab: platform.TabId, width: f64, height: f64) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const browser_platform = html.platform_state.of(realm) orelse return error.NoBrowserPlatform;
    const event: platform.PlatformEvent = .{ .kind = .window_rect_changed, .tab = tab, .rect = .{ .width = width, .height = height } };
    platform.adapter.postEvent(browser_platform, &event);
}

const page_markup =
    \\<!doctype html><body><iframe id=f></iframe>
    \\<script>
    \\globalThis.resizes = [];
    \\addEventListener('resize', (e) => resizes.push(innerWidth + 'x' + innerHeight + ':' + e.bubbles + e.cancelable + e.isTrusted));
    \\globalThis.narrow = matchMedia('(max-width: 600px)');
    \\globalThis.mediaChanges = [];
    \\narrow.addEventListener('change', (e) => mediaChanges.push(e.matches));
    \\</script>
;

fn loaded(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_markup, .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    // A frame has run (the load's reveal): the resize steps have seen the
    // first size, which fires nothing.
    try page.runScript("globalThis.settled = false; requestAnimationFrame(() => { settled = true; });");
    try until(browser, "settled");
    return page;
}

fn windowRectIsTheViewport() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    try expectEval(page, "[innerWidth, innerHeight, resizes.length, narrow.matches].join()", "1024,768,0,false");
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try postWindowRect(browser, tab, 500.7, 400);
    try until(browser, "resizes.length === 1 && mediaChanges.length === 1");
    try expectEval(page, "[innerWidth, innerHeight, resizes.join(), mediaChanges.join(), narrow.matches].join('|')", "500|400|500x400:falsefalsetrue|true|true");
    // A frame's viewport is its container's box, not the window's.
    try expectEval(page, "f.contentWindow.innerWidth !== 500", "true");

    // The same size again is no change: no second resize.
    try postWindowRect(browser, 0, 500, 400);
    try page.runScript("globalThis.settled = false; requestAnimationFrame(() => requestAnimationFrame(() => { settled = true; }));");
    try until(browser, "settled");
    try expectEval(page, "resizes.length", "1");
}

test "the platform's window rect is the top-level viewport: innerWidth, media queries and one resize at the next frame" {
    try onFreshThread(windowRectIsTheViewport);
}

fn overrideWinsWhileSet() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    const scope = browser.scope;

    try postWindowRect(browser, tab, 1200, 900);
    try until(browser, "innerWidth === 1200 && resizes.length === 1");
    // A host's override (Emulation.setDeviceMetricsOverride) wins.
    try testing.expect(browser_mod.viewport.setOverride(scope, tab, .{ .width = 360, .height = 640 }));
    try until(browser, "innerWidth === 360 && innerHeight === 640 && resizes.length === 2");
    try expectEval(page, "[narrow.matches, mediaChanges.join()].join('|')", "true|true");
    // The platform's window moving under the override changes nothing seen.
    try postWindowRect(browser, tab, 1300, 900);
    try page.runScript("globalThis.settled = false; requestAnimationFrame(() => requestAnimationFrame(() => { settled = true; }));");
    try until(browser, "settled");
    try expectEval(page, "[innerWidth, resizes.length].join()", "360,2");
    // Taken away: the window decides again.
    try testing.expect(browser_mod.viewport.setOverride(scope, tab, null));
    try until(browser, "innerWidth === 1300 && resizes.length === 3");
    try expectEval(page, "[narrow.matches, mediaChanges.join()].join('|')", "false|true,false");
    // An id no open traversable has is refused.
    try testing.expect(!browser_mod.viewport.setOverride(scope, tab + 1_000_000, .{ .width = 1, .height = 1 }));
}

test "a host's viewport override wins over the platform's window while set" {
    try onFreshThread(overrideWinsWhileSet);
}
