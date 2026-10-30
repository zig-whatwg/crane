//! Lane nav2 C1, in a Browser: history and navigation API traversals run on
//! the traversable's session history traversal queue (HTML 7.4.1.3), one at
//! a time, each waiting for the populations it starts.
//!
//! - The go() exception (integrator's ruling of 2026-10-27, from lane nav2's
//!   three-browser probe tmp/probes/nav2-tth-probe.html, on a TOP-LEVEL
//!   page): while an earlier delta traversal of a top-level traversable that
//!   takes its document elsewhere is queued or running, history.go()/back()/
//!   forward() on it is ignored; one out of range does not count. Chrome 156
//!   and Firefox 158 land as these cases expect (WPT
//!   traverse_the_history_2..5). A child navigable's coalesce instead: the
//!   pending target plus the new delta, one load (the axes probe,
//!   tmp/probes/nav2-axes-probe.html, Chrome = Firefox in all six variants;
//!   in Crane the History's navigable decides, so its self- and
//!   parent-called variants take one path).
//! - Same-document delta traversals keep the spec's queue: each applies.
//! - Liveness (condition 2): a frame its own unload handler removes during
//!   its traversal does not hold the queue - the next traversal runs.
//! - A Browser that ends with a traversal queued frees it (the test
//!   allocator checks).

const std = @import("std");
const testing = std.testing;
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
    // No snapshot: the startup path JavaScriptCore runs on.
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Run the Browser's tasks until `condition` (a script) is "true" (bounded
/// at 5 s).
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

/// Run the Browser's tasks for about `ms` milliseconds.
fn settle(browser: *browser_mod.Browser, ms: usize) !void {
    var waited: usize = 0;
    while (waited < ms) : (waited += 10) _ = try browser.runEventLoopBlocking(10);
}

/// A page whose frame has six cross-document entries - its srcdoc document
/// and about:blank?2 .. ?6, each pushed after the one before has loaded -
/// and records each frame load from then on in `loads`.
fn sixEntries(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>1</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '1')");
    var n: u8 = 2;
    while (n <= 6) : (n += 1) {
        var script: [96]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "frames[0].location.href = 'about:blank?{d}';", .{n}));
        var condition: [128]u8 = undefined;
        try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(frames[0].location.href === 'about:blank?{d}' && frames[0].document.readyState === 'complete')", .{n}));
    }
    try page.runScript("globalThis.loads = []; document.querySelector('iframe').onload = () => loads.push(frames[0].location.href);");
    return page;
}

/// A top-level page with six cross-document entries: about:blank?1 .. ?6,
/// each navigated to after the one before has loaded.
fn sixTopLevelEntries(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><p>0</p>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete')");
    var n: u8 = 1;
    while (n <= 6) : (n += 1) {
        var script: [96]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "location.href = 'about:blank?{d}';", .{n}));
        var condition: [128]u8 = undefined;
        try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(location.href === 'about:blank?{d}' && document.readyState === 'complete')", .{n}));
    }
    return page;
}

/// From the top-level page's sixth entry, `calls` (a script making the
/// go() calls); the page lands on `expected` and stays there.
fn landsOn(calls: []const u8, expected: []const u8) !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try sixTopLevelEntries(browser);
    try page.runScript(calls);
    var condition: [128]u8 = undefined;
    try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(location.href === '{s}' && document.readyState === 'complete')", .{expected}));
    try settle(browser, 300);
    try expectEval(page, "location.href", expected);
}

fn tth2() !void {
    try landsOn("for (const d of [-3, -2, 1]) history.go(d);", "about:blank?3");
}

fn tth3() !void {
    try landsOn("for (const d of [-2, -1, 3]) history.go(d);", "about:blank?4");
}

fn tth4() !void {
    try landsOn("for (const d of [-10, -1, -2]) history.go(d);", "about:blank?5");
}

fn tth5() !void {
    try landsOn("for (const d of [10, -1, -2]) history.go(d);", "about:blank?5");
}

fn fromPagehide() !void {
    try landsOn(
        \\addEventListener('pagehide', () => history.go(-1));
        \\history.go(-3);
    , "about:blank?3");
}

/// A child navigable coalesces: from the frame's sixth entry, go(-3),
/// go(-2), go(1) in one task make one traversal by -4, to ?2, with one load.
fn childCoalesces() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try sixEntries(browser);
    try page.runScript("for (const d of [-3, -2, 1]) frames[0].history.go(d);");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?2' && frames[0].document.readyState === 'complete')");
    try settle(browser, 300);
    try expectEval(page, "loads.join()", "about:blank?2");
}

/// lane nav2's axes probe (tmp/probes/nav2-axes-probe.html): three entries -
/// ?1, then ?2 (`cross`) or ?1#2 (`crossSame`, a fragment step), then ?3 -
/// and history.back(); history.back() in one task. `frame`: in an iframe,
/// the parent calling the frame's history; else the top-level page itself.
fn axes(frame: bool, cross_same: bool, expected: []const u8) !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const markup = if (frame) "<!doctype html><body><iframe srcdoc='<p>0</p>'></iframe></body>" else "<!doctype html><p>0</p>";
    try page.loadHTML(markup, .{ .base_url = "http://example.test/top" });
    const w = if (frame) "frames[0]" else "window";
    var buffer: [256]u8 = undefined;
    try runUntil(browser, page, try std.fmt.bufPrint(&buffer, "String(document.readyState === 'complete' && {s}.document.readyState === 'complete')", .{w}));
    const steps = if (cross_same) [_][]const u8{ "about:blank?1", "about:blank?1#2", "about:blank?3" } else [_][]const u8{ "about:blank?1", "about:blank?2", "about:blank?3" };
    for (steps) |url| {
        var script: [128]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "{s}.location.href = '{s}';", .{ w, url }));
        try runUntil(browser, page, try std.fmt.bufPrint(&buffer, "String({s}.location.href === '{s}' && {s}.document.readyState === 'complete')", .{ w, url, w }));
        try settle(browser, 20);
    }
    if (frame) try page.runScript("globalThis.loads = []; document.querySelector('iframe').onload = () => loads.push(frames[0].location.href);");
    try page.runScript(try std.fmt.bufPrint(&buffer, "{s}.history.back(); {s}.history.back();", .{ w, w }));
    try runUntil(browser, page, try std.fmt.bufPrint(&buffer, "String({s}.location.href === '{s}' && {s}.document.readyState === 'complete')", .{ w, expected, w }));
    try settle(browser, 300);
    try expectEval(page, try std.fmt.bufPrint(&buffer, "{s}.location.href", .{w}), expected);
    // In a frame, only the final target loaded.
    if (frame) try expectEval(page, "loads.join()", expected);
}

fn axesA() !void {
    try axes(false, false, "about:blank?2");
}

fn axesB() !void {
    try axes(false, true, "about:blank?1#2");
}

fn axesC() !void {
    try axes(true, false, "about:blank?1");
}

fn axesD() !void {
    try axes(true, true, "about:blank?1");
}

test "axes a: a top-level page's back(), back() across cross-document entries lands on the first target" {
    try onFreshThread(axesA);
}

test "axes b: a top-level page's back(), back() with a fragment entry between lands on the first target" {
    try onFreshThread(axesB);
}

test "axes c: a frame's back(), back() across cross-document entries coalesce: -2, one load" {
    try onFreshThread(axesC);
}

test "axes d: a frame's back(), back() with a fragment entry between coalesce: -2, one load" {
    try onFreshThread(axesD);
}

test "go(-3), go(-2), go(1) in one task: the first cross-document traversal wins (traverse_the_history_2)" {
    try onFreshThread(tth2);
}

test "go(-2), go(-1), go(3) in one task: the first wins (traverse_the_history_3)" {
    try onFreshThread(tth3);
}

test "go(-10), go(-1), go(-2): an out-of-range go() does not count, the next wins (traverse_the_history_4)" {
    try onFreshThread(tth4);
}

test "go(10), go(-1), go(-2): the same forward (traverse_the_history_5)" {
    try onFreshThread(tth5);
}

test "a go() from the leaving page's pagehide is ignored while its traversal is in progress" {
    try onFreshThread(fromPagehide);
}

test "a child navigable's delta traversals coalesce into one, with one load" {
    try onFreshThread(childCoalesces);
}

fn sameDocumentDeltas() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>1</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '1')");
    try page.runScript(
        \\// Absolute: a srcdoc document's base URL is its parent's.
        \\for (const p of ['#p1', '#p2', '#p3']) frames[0].history.pushState(null, '', 'about:srcdoc' + p);
        \\frames[0].history.back();
        \\frames[0].history.back();
    );
    try runUntil(browser, page, "String(frames[0].location.hash === '#p1')");
    try settle(browser, 200);
    try expectEval(page, "frames[0].location.hash", "#p1");
}

test "same-document delta traversals keep the spec's queue: two back() calls go back two entries" {
    try onFreshThread(sameDocumentDeltas);
}

fn removedDuringTraversal() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>1</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '1')");
    try page.runScript("history.pushState(null, '', '?t1');");
    try page.runScript("frames[0].location.href = 'about:blank?2';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?2' && frames[0].document.readyState === 'complete')");
    // The frame's document removes its own frame as the traversal unloads it;
    // then the top's navigation API traversal, queued behind, must still run.
    try page.runScript(
        \\frames[0].addEventListener('unload', () => document.querySelector('iframe').remove());
        \\frames[0].history.back();
        \\navigation.back();
    );
    try runUntil(browser, page, "String(!location.search.includes('t1'))");
    try expectEval(page, "String(document.querySelector('iframe'))", "null");
}

test "a frame removed by its own unload handler during its traversal does not hold the queue: the next traversal runs" {
    try onFreshThread(removedDuringTraversal);
}

fn endsWithTraversalQueued() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try sixEntries(browser);
    // Queued and not run: the Browser ends first.
    try page.runScript("frames[0].history.back(); navigation.back();");
}

test "a Browser that ends with traversals queued frees them" {
    try onFreshThread(endsWithTraversalQueued);
}
