//! Lane nr1, in a Browser: a same-document history.back() stops a
//! cross-document navigation of the same navigable that started before it,
//! even when the navigation's response is there before the traversal's steps
//! have begun.
//!
//! HTML "apply the history step" step 8.4 sets the navigable's ongoing
//! navigation to "traversal" on the session history traversal queue, which
//! the spec runs in parallel; the task "attempt to populate the history
//! entry's document" step 5 queues for the response then finds, at its step
//! 5.1, that the navigation is no longer the ongoing one. Crane runs the
//! queue from service tasks on the navigable's loop, and the response's task
//! lets it catch up first (HTMLIFrameElement runCommit,
//! TraversalQueue.catchUp).
//!
//! The navigations here go to about:blank?n, which needs no network: the
//! response's task is queued inside navigate, ahead of the service task
//! history.back() asks for. Before the fix that task marked the navigation
//! as committing, step 8.4 left it alone, and it committed after the
//! traversal. Chrome and Safari stop it, Firefox does not
//! (tests/wpt/crane/nr1-same-document-back-stops-cross-document-nav.html,
//! the blob: URL case: 2026-11-16, Chrome 157 and Safari 27.2 pass, Firefox
//! 160 fails).

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
    return browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const value = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn settle(browser: *browser_mod.Browser, ms: usize) !void {
    var waited: usize = 0;
    while (waited < ms) : (waited += 10) _ = try browser.runEventLoopBlocking(10);
}

/// A page whose frame shows about:blank?1#b, with the entries about:blank?1,
/// #a and #b of that one document behind it, everything settled; `loads`
/// records the frame's load events from here on.
fn frameWithFragmentEntries(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>0</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '0')");
    try page.runScript("frames[0].location.href = 'about:blank?1';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1' && frames[0].document.readyState === 'complete')");
    try settle(browser, 20);
    for ([_][]const u8{ "#a", "#b" }) |hash| {
        var script: [64]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "frames[0].location.hash = '{s}';", .{hash}));
        try settle(browser, 20);
    }
    try expectEval(page, "frames[0].location.href", "about:blank?1#b");
    try page.runScript("globalThis.loads = []; document.querySelector('iframe').onload = () => loads.push(frames[0].location.href);");
    return page;
}

fn backStopsNavigationWithInstantResponse() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameWithFragmentEntries(browser);
    try page.runScript("frames[0].location.href = 'about:blank?9'; frames[0].history.back();");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1#a')");
    try settle(browser, 200);
    // The traversal went back one entry of the same document, and the
    // navigation it stopped never committed - not before it, not after.
    try expectEval(page, "loads.join()", "");
    try expectEval(page, "frames[0].location.href", "about:blank?1#a");
}

test "a same-document back() stops a navigation whose response needs no network (apply the history step 8.4, attempt to populate 5.1)" {
    try onFreshThread(backStopsNavigationWithInstantResponse);
}

fn backBehindFragmentNavigationsStopsNavigation() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameWithFragmentEntries(browser);
    // Two synchronous navigations first: their "finalize a same-document
    // navigation" steps are on the traversal queue ahead of back()'s, each
    // a service task of its own.
    try page.runScript(
        \\frames[0].location.hash = '#c';
        \\frames[0].location.hash = '#d';
        \\frames[0].location.href = 'about:blank?9';
        \\frames[0].history.back();
    );
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1#c')");
    try settle(browser, 200);
    try expectEval(page, "loads.join()", "");
    try expectEval(page, "frames[0].location.href", "about:blank?1#c");
}

test "a same-document back() queued behind two fragment navigations' finalize steps still stops the navigation" {
    try onFreshThread(backBehindFragmentNavigationsStopsNavigation);
}

fn navigationAloneStillCommits() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameWithFragmentEntries(browser);
    // The control: with no traversal the navigation commits, and with a
    // traversal appended AFTER its commit the traversal goes back to the
    // document it left.
    try page.runScript("frames[0].location.href = 'about:blank?9';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?9' && frames[0].document.readyState === 'complete')");
    try settle(browser, 50);
    try expectEval(page, "loads.join()", "about:blank?9");
    try page.runScript("frames[0].history.back();");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1#b' && frames[0].document.readyState === 'complete')");
    try settle(browser, 50);
    try expectEval(page, "frames[0].location.href", "about:blank?1#b");
}

test "without a traversal the navigation commits, and a later back() returns to the document it left" {
    try onFreshThread(navigationAloneStillCommits);
}
