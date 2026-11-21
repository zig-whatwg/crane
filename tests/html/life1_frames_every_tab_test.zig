//! Rendering opportunities for every tab of every Browser (CDP P0b, lane
//! life1): each Browser's event loop has its own frame clock
//! (src/browser/rendering.zig, EventLoop.frames), and one rendering task
//! visits every fully active, visible document of the loop - the host's page,
//! each popup a page opened, and each tab a host opens (Target.createTarget:
//! lane cdph's host-opened tabs join here when they land) - so a
//! requestAnimationFrame in any of them ticks, on its own Browser's thread,
//! whatever another Browser does.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// Run `browser`'s loop until `condition` (a script in its page) is true,
/// bounded at 5 s.
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

/// A page whose animation frame callback re-arms itself, counting frames,
/// and a popup it opens doing the same.
const markup =
    \\<!doctype html><body><script>
    \\globalThis.frames_seen = 0;
    \\(function tick() { frames_seen++; requestAnimationFrame(tick); })();
    \\</script>
;

fn tabsOfOneBrowser() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete' && frames_seen >= 3");
    // A second top-level traversable of the same Browser - a popup, the
    // shape a host-opened tab has - gets rendering opportunities on the
    // same clock: its own frames count up beside the page's.
    try page.runScript(
        \\globalThis.popup = window.open('about:blank', '_blank');
        \\popup.frames_seen = 0;
        \\(function tick() { popup.frames_seen++; popup.requestAnimationFrame(tick); })();
    );
    try until(browser, "popup.frames_seen >= 3");
    const before = try page.evaluateScriptToString("frames_seen", testing.allocator);
    defer testing.allocator.free(before);
    try until(browser, "popup.frames_seen >= 6");
    const after = try page.evaluateScriptToString("frames_seen > " ++ "0", testing.allocator);
    defer testing.allocator.free(after);
    try testing.expectEqualStrings("true", after);
}

test "every top-level traversable of a Browser gets animation frames from its one clock" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            tabsOfOneBrowser() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn ownBrowserTicks(failure: *?anyerror) void {
    const body = struct {
        fn run() !void {
            const browser = try startBrowser();
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML(markup, .{ .base_url = "http://example.test/one" });
            try until(browser, "frames_seen >= 10");
        }
    }.run;
    body() catch |err| {
        failure.* = err;
    };
}

test "two Browsers on two threads each tick their own animation frames" {
    var failures: [2]?anyerror = .{ null, null };
    const first = try std.Thread.spawn(.{}, ownBrowserTicks, .{&failures[0]});
    const second = try std.Thread.spawn(.{}, ownBrowserTicks, .{&failures[1]});
    first.join();
    second.join();
    for (failures) |f| if (f) |err| return err;
}
