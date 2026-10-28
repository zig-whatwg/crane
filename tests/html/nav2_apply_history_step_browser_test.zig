//! Lane nav2 C2, in a Browser: "apply the history step" (HTML 7.4.6.1) as
//! queue items, with its per-navigable tasks.
//!
//! - Step 12 queues one task per changing navigable, and a same-document
//!   change goes on in an afterPotentialUnloads task of its own (14.10.2):
//!   every changing navigable's traverse navigate event fires before any of
//!   their popstate events.
//! - Step 8.4: a navigable whose target entry is not its active document is
//!   "traversal" from the apply's start until its document unloads; navigate
//!   step 18 ignores navigations of it meanwhile - one from its own traverse
//!   navigate handler fires no navigate event and loads nothing.
//! - Reload is "apply the reload history step" on the queue: a child's
//!   location.reload() behind a pending traversal reloads the entry the
//!   traversal went to. A top-level page's history.go(0) follows the stated
//!   exceptions (integrator's ruling from lane nav2's probe): ignored while a
//!   cross-document delta traversal is pending, and cancelled by a later one.
//! - "Destroy a child navigable" leaves the other documents' History length
//!   to its queued "update for navigable creation/destruction" (step 18).
//! - Liveness (integrator's condition 2): a navigable removed by its own
//!   traverse navigate handler, or before its step-18 task runs, does not
//!   hold the queue; a Browser that ends with an apply's tasks queued frees
//!   them.

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

/// A top-level page with two srcdoc frames, loaded.
fn twoFrames(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>a</p>'></iframe><iframe srcdoc='<p>b</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'a' && frames[1].document.body?.textContent === 'b')");
    return page;
}

/// A page whose frame has entries ?1 and ?2 (cross-document), loaded.
fn frameOnSecond(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>0</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '0')");
    for ([_][]const u8{ "about:blank?1", "about:blank?2" }) |url| {
        var script: [96]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "frames[0].location.href = '{s}';", .{url}));
        var condition: [160]u8 = undefined;
        try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(frames[0].location.href === '{s}' && frames[0].document.readyState === 'complete')", .{url}));
        try settle(browser, 20);
    }
    try page.runScript("globalThis.loads = []; document.querySelector('iframe').onload = () => loads.push(frames[0].location.href);");
    return page;
}

fn navigateEventsBeforePopstate() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFrames(browser);
    // Each frame pushes one same-document entry: steps 1 and 2.
    try page.runScript(
        \\frames[0].history.pushState(null, '', 'about:srcdoc#a1');
        \\frames[1].history.pushState(null, '', 'about:srcdoc#b1');
        \\globalThis.log = [];
        \\for (const [i, name] of [[0, 'a'], [1, 'b']]) {
        \\  frames[i].navigation.onnavigate = () => log.push('navigate-' + name);
        \\  frames[i].onpopstate = () => log.push('popstate-' + name);
        \\}
        \\history.go(-2);
    );
    try runUntil(browser, page, "String(log.length === 4)");
    try expectEval(page, "log.join()", "navigate-a,navigate-b,popstate-a,popstate-b");
    try expectEval(page, "frames[0].location.hash + frames[1].location.hash", "");
}

test "a traversal that changes two frames fires both traverse navigate events before either popstate (steps 12 and 14.10)" {
    try onFreshThread(navigateEventsBeforePopstate);
}

fn navigationFromTraverseHandlerIgnored() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameOnSecond(browser);
    try page.runScript(
        \\globalThis.events = [];
        \\frames[0].navigation.onnavigate = e => {
        \\  events.push(e.navigationType);
        \\  if (e.navigationType === 'traverse') frames[0].location.href = 'about:blank?9';
        \\};
        \\frames[0].history.back();
    );
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1' && frames[0].document.readyState === 'complete')");
    try settle(browser, 200);
    // The traverse event only: the navigation it started was ignored (navigate
    // step 18), so no push navigate event fired and ?9 never loaded.
    try expectEval(page, "events.join()", "traverse");
    try expectEval(page, "loads.join()", "about:blank?1");
    try expectEval(page, "frames[0].location.href", "about:blank?1");
}

test "a navigation of a traversing navigable - from its own traverse navigate handler - is ignored (step 8.4, navigate step 18)" {
    try onFreshThread(navigationFromTraverseHandlerIgnored);
}

fn childReloadBehindTraversal() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameOnSecond(browser);
    // Queued in order: the traversal, then the reload of the entry it goes to.
    try page.runScript("frames[0].history.back(); frames[0].location.reload();");
    try runUntil(browser, page, "String(loads.length === 2)");
    try settle(browser, 200);
    try expectEval(page, "loads.join()", "about:blank?1,about:blank?1");
    try expectEval(page, "frames[0].navigation.activation.navigationType", "reload");
}

test "a child's location.reload() behind its pending traversal reloads the entry the traversal went to (apply the reload history step)" {
    try onFreshThread(childReloadBehindTraversal);
}

/// A top-level page with six cross-document entries: about:blank?1 .. ?6.
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

/// From the sixth entry, `calls`; the page lands on `expected`, made by a
/// traversal (not reloaded after), and stays there.
fn goZeroLandsOn(calls: []const u8, expected: []const u8) !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try sixTopLevelEntries(browser);
    try page.runScript(calls);
    var condition: [160]u8 = undefined;
    try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(location.href === '{s}' && document.readyState === 'complete')", .{expected}));
    try settle(browser, 300);
    try expectEval(page, "location.href", expected);
    try expectEval(page, "navigation.activation.navigationType", "traverse");
}

fn goZeroFirst() !void {
    try goZeroLandsOn("history.go(0); history.go(-2);", "about:blank?4");
}

fn goZeroMiddle() !void {
    try goZeroLandsOn("history.go(-2); history.go(0); history.go(-1);", "about:blank?4");
}

fn goZeroLast() !void {
    try goZeroLandsOn("history.go(-2); history.go(0);", "about:blank?4");
}

test "go0_first: a top-level go(0), go(-2) - the traversal cancels the queued reload" {
    try onFreshThread(goZeroFirst);
}

test "go0_middle: a top-level go(-2), go(0), go(-1) - the reload and the second traversal are ignored" {
    try onFreshThread(goZeroMiddle);
}

test "go0_last: a top-level go(-2), go(0) - the reload is ignored while the traversal is pending" {
    try onFreshThread(goZeroLast);
}

fn destructionUpdatesLengthLater() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>f</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'f')");
    try page.runScript(
        \\frames[0].history.pushState(null, '', 'about:srcdoc#1');
        \\frames[0].history.pushState(null, '', 'about:srcdoc#2');
    );
    try expectEval(page, "String(history.length)", "3");
    // "Destroy a child navigable": its entries go at once, and the parent's
    // History length moves with the queued update's step 18.
    try page.runScript("document.querySelector('iframe').remove(); globalThis.at_once = history.length;");
    try expectEval(page, "String(at_once)", "3");
    try runUntil(browser, page, "String(history.length === 1)");
}

test "a destroyed frame's entries leave the parent's history.length at its queued update, not at once" {
    try onFreshThread(destructionUpdatesLengthLater);
}

fn removedInTraverseHandler() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>1</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '1')");
    try page.runScript("history.pushState(null, '', '?t1');");
    try page.runScript("frames[0].location.href = 'about:blank?2';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?2' && frames[0].document.readyState === 'complete')");
    // The frame's traverse navigate event (12.7) removes the frame; the
    // top's navigation API traversal, queued behind, must still run.
    try page.runScript(
        \\frames[0].navigation.onnavigate = () => document.querySelector('iframe').remove();
        \\frames[0].history.back();
        \\navigation.back();
    );
    try runUntil(browser, page, "String(!location.search.includes('t1'))");
    try expectEval(page, "String(document.querySelector('iframe'))", "null");
}

test "a frame removed by its own traverse navigate handler does not hold the queue: the next traversal runs" {
    try onFreshThread(removedInTraverseHandler);
}

fn endsWithChangeTasksQueued() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFrames(browser);
    try page.runScript(
        \\frames[0].history.pushState(null, '', 'about:srcdoc#a1');
        \\frames[1].history.pushState(null, '', 'about:srcdoc#b1');
        \\history.go(-2);
    );
    // The apply's service task runs; its step-12 tasks are queued, not run,
    // when the Browser ends.
    _ = try browser.runEventLoopBlocking(0);
}

test "a Browser that ends with an apply's per-navigable tasks queued frees them" {
    try onFreshThread(endsWithChangeTasksQueued);
}
