//! Lane nav2 batch 7, S2: the opener link between browsing contexts.
//!
//! - Window open steps 16.2: window.open() on an existing navigable - a frame
//!   found by name - sets that navigable's active browsing context's opener
//!   browsing context to sourceDocument's browsing context, also for an empty
//!   URL that navigates nothing (windows/embedded-opener.html).
//! - A browsing context can name an opener that is freed before it: a popup
//!   opened from a frame whose element is removed and collected first. The
//!   freed context's openees then answer window.opener with null, never with
//!   what the freed memory holds (BrowsingContext.deinit clears every live
//!   context's link to it, as Blink's Frame::Detach clears its openees'
//!   openers through OpenedFrameTracker). The feature queue's "LIFETIME: a
//!   both-ends opener link" (2026-10-18, Codex row 80 Q3).
//!
//! testing.allocator poisons what it frees: a read through a dangling opener
//! link fails here.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

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
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

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

/// Collect, and let the tasks a collection queues run, a few times over.
fn collect(browser: *browser_mod.Browser) !void {
    for (0..3) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

fn loadPage(browser: *browser_mod.Browser, markup: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "http://example.test/opener" });
    try until(browser, "document.readyState === 'complete'");
    return page;
}

fn openOnNamedFrame() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><iframe name=named></iframe>");
    try expectEval(page, "frames[0].opener === null", "true");
    // An empty URL navigates nothing, and the opener is still set (16.2).
    try expectEval(page, "window.open('', 'named') === frames[0]", "true");
    try expectEval(page, "frames[0].opener === window", "true");
    // noopener sets none (and returns null).
    try page.loadHTML("<!doctype html><iframe name=other></iframe>", .{ .base_url = "http://example.test/opener2" });
    try until(browser, "document.readyState === 'complete'");
    try expectEval(page, "window.open('', 'other', 'noopener') === null && frames[0].opener === null", "true");
}

test "window.open() on a frame by name sets the frame's opener, an empty URL included; noopener sets none" {
    try onFreshThread(openOnNamedFrame);
}

fn popupOfRemovedFrame() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "a popup outlives the frame that opened it, which is what this tests");
    const page = try loadPage(browser, "<!doctype html><iframe id=f srcdoc='<p>frame'></iframe>");
    try until(browser, "frames[0].document.readyState === 'complete'");
    // The frame's own script opens the popup: the frame is its opener.
    try page.runScript(
        \\const s = frames[0].document.createElement('script');
        \\s.textContent = "parent.popup = window.open('about:blank', 'p1'); parent.openerWasFrame = parent.popup.opener === window;";
        \\frames[0].document.body.appendChild(s);
    );
    try expectEval(page, "openerWasFrame", "true");
    // The frame goes first, and is collected: its browsing context is freed
    // while the popup lives.
    try page.runScript("document.getElementById('f').remove();");
    try collect(browser);
    try expectEval(page, "popup.opener", "null");
}

test "a popup opened from a frame whose element is removed and collected first answers opener with null" {
    try onFreshThread(popupOfRemovedFrame);
}
