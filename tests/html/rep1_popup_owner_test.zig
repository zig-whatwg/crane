//! A popup belongs to its Browser, not to the window that opened it (lane
//! rep1 batch 2). HTML 7.3.1.2: a top-level traversable is the user agent's;
//! window.opener names the opener BROWSING CONTEXT, a reference that goes when
//! that context goes. Blink keeps a popup's frame as the main frame of its own
//! Page and clears the opener on detach (OpenedFrameTracker); Chrome 157 and
//! Firefox 159 keep a popup running when the window that opened it closes or
//! its iframe is removed (tmp/probes/rep1-popup-owner).
//!
//! So nothing about the opener's lifetime ends a popup: not the removal of the
//! iframe that opened it, not the closing of the popup that opened it, and its
//! Browser's end closes every popup it has - in any order - before its page,
//! leaving no realm for the agent's end (protocol_agents' log.err, which fails
//! a test).
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

/// Collect, and let the tasks a collection queues run - a detached realm's
/// end among them - a few times over.
fn collect(browser: *browser_mod.Browser) !void {
    for (0..3) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

fn loadPage(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>opener</title><body>", .{ .base_url = "http://example.test/page" });
    try until(browser, "document.readyState === 'complete'");
    return page;
}

/// Whether the popup held as `name` on the page still runs tasks: one of its
/// timers sets a marker the page then reads.
fn expectPopupRuns(browser: *browser_mod.Browser, comptime name: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript("globalThis.mark = Math.random(); " ++ name ++ ".setTimeout('window.seen = ' + mark, 0);");
    try until(browser, name ++ ".seen === mark");
}

fn removedFrameKeepsPopup() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadPage(browser);
    try page.runScript(
        \\globalThis.frame = document.createElement('iframe');
        \\frame.srcdoc = '<script>parent.popup = window.open("about:blank", "p");<\/script>';
        \\document.body.append(frame);
    );
    try until(browser, "globalThis.popup !== undefined && popup !== null");
    try expectEval(page, "popup.opener === frame.contentWindow", "true");
    // "Destroy a child navigable": the frame's documents go; its popup does not.
    try page.runScript("frame.remove();");
    try collect(browser);
    try expectPopupRuns(browser, "popup");
    try expectEval(page, "[popup.closed, popup.opener === null].join()", "false,true");
}

test "a popup keeps running, its opener gone, after the iframe that opened it is removed" {
    try onFreshThread(removedFrameKeepsPopup);
}

fn closedOpenerKeepsPopup() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadPage(browser);
    // An iframe opens P1, P1 opens P2; P1 closes; the iframe is removed:
    // every window between P2 and the page is gone.
    try page.runScript(
        \\globalThis.frame = document.createElement('iframe');
        \\frame.srcdoc = '<script>parent.p1 = window.open("about:blank", "p1");<\/script>';
        \\document.body.append(frame);
    );
    try until(browser, "globalThis.p1 !== undefined && p1 !== null");
    // P1's own script opens P2 (window.open's opener is the entry global's
    // navigable: a task of P1's).
    try page.runScript("p1.setTimeout('window.p2 = window.open(\"about:blank\", \"p2\")', 0);");
    try until(browser, "p1.p2 !== undefined && p1.p2 !== null");
    try page.runScript("globalThis.p2 = p1.p2;");
    try expectEval(page, "p2.opener === p1", "true");
    try page.runScript("p1.close();");
    try until(browser, "p1.closed");
    try page.runScript("frame.remove();");
    try collect(browser);
    try expectPopupRuns(browser, "p2");
    try expectEval(page, "[p2.closed, p2.opener === null].join()", "false,true");
}

test "a popup keeps running, with no opener, after the popup that opened it closed and that popup's iframe went" {
    try onFreshThread(closedOpenerKeepsPopup);
}

fn browserEndWithPopups(comptime close_first: ?[]const u8) !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadPage(browser);
    // P1 opened by the page, P2 opened by P1 (its script).
    try page.runScript("globalThis.p1 = window.open('about:blank', 'p1'); p1.setTimeout('window.p2 = window.open(\"about:blank\", \"p2\")', 0);");
    try until(browser, "p1.p2 !== undefined && p1.p2 !== null");
    try page.runScript("globalThis.p2 = p1.p2;");
    try expectPopupRuns(browser, "p1");
    try expectPopupRuns(browser, "p2");
    // One of them closed first by script, then the Browser ends with the
    // other: no realm left behind either way.
    if (close_first) |name| {
        try page.runScript(name ++ ".close();");
        try until(browser, name ++ ".closed");
        try collect(browser);
    }
}

fn browserEndBothOpen() !void {
    try browserEndWithPopups(null);
}
fn browserEndOpenerClosedFirst() !void {
    try browserEndWithPopups("p1");
}
fn browserEndOpeneeClosedFirst() !void {
    try browserEndWithPopups("p2");
}

test "the Browser's end closes two popups, one opened by the other, before its page: both open, or either closed first" {
    try onFreshThread(browserEndBothOpen);
    try onFreshThread(browserEndOpenerClosedFirst);
    try onFreshThread(browserEndOpeneeClosedFirst);
}
