//! Lane nav2 E, in a Browser: synchronous (same-document) navigations finalize
//! on the traversable's session history traversal queue ("finalize a
//! same-document navigation" as synchronous navigation steps targeting the
//! navigable), so a traversal queued before them computes its endpoint from
//! the original placement, and their finalize jumps the waiting traversal
//! ("apply the history step" 14.1) before it changes the document:
//!
//! - an anchor's click handler calls history.back() and the anchor's own
//!   fragment navigation follows: popstate fires for the fragment (at once),
//!   then for the traversal's target, the entry before the one the back() was
//!   called on (WPT overlapping-navigations-and-traversals/
//!   anchor-fragment-history-back-on-click);
//! - a frame's history.back() followed by a fragment navigation or a
//!   pushState() ends where the back() was going, and keeps the new entry in
//!   the history (same-document-traversal-same-document-nav,
//!   cross-document-traversal-same-document-nav);
//! - two synchronous navigations in one task keep both entries
//!   (whatwg/html#10232).

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

fn loadedPage(browser: *browser_mod.Browser, markup: []const u8, condition: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, condition);
    try settle(browser, 20);
    return page;
}

fn anchorBackOnClick() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><body></body>", "String(document.readyState === 'complete')");
    try page.runScript(
        \\location.hash = '#1';
        \\location.hash = '#2';
        \\globalThis.before = history.length;
        \\globalThis.navigations = [];
        \\globalThis.lengths = [];
        \\onpopstate = () => { navigations.push(location.hash); lengths.push(history.length); };
        \\const anchor = document.createElement('a');
        \\anchor.href = '#3';
        \\anchor.onclick = () => history.back();
        \\anchor.click();
        \\globalThis.after_click = location.hash + ' ' + (history.length - before);
    );
    // The fragment navigation is synchronous: #3 and one more entry, at once.
    try expectEval(page, "after_click", "#3 1");
    try runUntil(browser, page, "String(navigations.length === 2)");
    try settle(browser, 50);
    // The traversal went to the entry before #2, where back() was called -
    // after #3's finalize had jumped it - and #3 stays in the history.
    try expectEval(page, "navigations.join()", "#3,#1");
    try expectEval(page, "location.hash", "#1");
    try expectEval(page, "lengths.map(l => l - before).join()", "1,1");
    try expectEval(page, "String(history.length - before)", "1");
    try expectEval(page, "String(navigation.currentEntry.index === navigation.entries().length - 3)", "true");
    try expectEval(page, "navigation.entries().slice(-3).map(e => new URL(e.url).hash).join()", "#1,#2,#3");
}

test "an anchor whose click handler calls history.back(): popstate for its fragment, then for the entry before (anchor-fragment-history-back-on-click)" {
    try onFreshThread(anchorBackOnClick);
}

fn frameOnFragment(browser: *browser_mod.Browser) !*browser_mod.Context {
    const page = try loadedPage(browser, "<!doctype html><body><iframe srcdoc='<p>f</p>'></iframe></body>", "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'f')");
    try page.runScript("frames[0].location.hash = '#1';");
    try settle(browser, 20);
    try page.runScript("frames[0].location.hash = '#2';");
    try settle(browser, 20);
    try page.runScript("globalThis.before = history.length;");
    return page;
}

fn sameDocumentTraversalThenFragment() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameOnFragment(browser);
    try page.runScript(
        \\frames[0].history.back();
        \\globalThis.sync = [frames[0].location.hash];
        \\frames[0].location.hash = '#3';
        \\sync.push(frames[0].location.hash);
    );
    try expectEval(page, "sync.join()", "#2,#3");
    try runUntil(browser, page, "String(frames[0].location.hash === '#1')");
    try settle(browser, 50);
    try expectEval(page, "frames[0].location.hash", "#1");
    try expectEval(page, "String(history.length - before)", "1");
    try expectEval(page, "frames[0].navigation.entries().map(e => new URL(e.url).hash).join()", ",#1,#2,#3");
}

test "a frame's same-document back() then a fragment navigation: it ends where back() was going, with the new entry kept (same-document-traversal-same-document-nav)" {
    try onFreshThread(sameDocumentTraversalThenFragment);
}

fn sameDocumentTraversalThenPushState() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameOnFragment(browser);
    try page.runScript(
        \\frames[0].history.back();
        \\frames[0].history.pushState(null, '', 'about:srcdoc#3');
        \\globalThis.sync = frames[0].location.hash;
    );
    try expectEval(page, "sync", "#3");
    try runUntil(browser, page, "String(frames[0].location.hash === '#1')");
    try settle(browser, 50);
    try expectEval(page, "frames[0].location.hash", "#1");
    try expectEval(page, "String(history.length - before)", "1");
}

test "a frame's same-document back() then pushState(): it ends where back() was going" {
    try onFreshThread(sameDocumentTraversalThenPushState);
}

/// A page whose frame has entries ?1 and ?2 (cross-document), loaded.
fn frameOnSecond(browser: *browser_mod.Browser) !*browser_mod.Context {
    const page = try loadedPage(browser, "<!doctype html><body><iframe srcdoc='<p>0</p>'></iframe></body>", "String(document.readyState === 'complete' && frames[0].document.body?.textContent === '0')");
    for ([_][]const u8{ "about:blank?1", "about:blank?2" }) |url| {
        var script: [96]u8 = undefined;
        try page.runScript(try std.fmt.bufPrint(&script, "frames[0].location.href = '{s}';", .{url}));
        var condition: [160]u8 = undefined;
        try runUntil(browser, page, try std.fmt.bufPrint(&condition, "String(frames[0].location.href === '{s}' && frames[0].document.readyState === 'complete')", .{url}));
        try settle(browser, 20);
    }
    try page.runScript("globalThis.before = history.length;");
    return page;
}

fn crossDocumentTraversalThenFragment() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try frameOnSecond(browser);
    try page.runScript(
        \\frames[0].history.back();
        \\globalThis.sync = [frames[0].location.href];
        \\frames[0].location.hash = '#3';
        \\sync.push(frames[0].location.href);
    );
    try expectEval(page, "sync.join()", "about:blank?2,about:blank?2#3");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?1' && frames[0].document.readyState === 'complete')");
    try settle(browser, 50);
    try expectEval(page, "frames[0].location.href", "about:blank?1");
    try expectEval(page, "String(history.length - before)", "1");
}

test "a frame's cross-document back() then a fragment navigation: the fragment entry is added and the traversal lands one step back (cross-document-traversal-same-document-nav)" {
    try onFreshThread(crossDocumentTraversalThenFragment);
}

fn twoPushesInOneTask() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><body></body>", "String(document.readyState === 'complete')");
    try page.runScript(
        \\globalThis.before = history.length;
        \\history.pushState('a', '', '#a');
        \\history.pushState('b', '', '#b');
        \\history.replaceState('b2', '', '#b2');
        \\globalThis.sync = (history.length - before) + ' ' + history.state;
    );
    try expectEval(page, "sync", "2 b2");
    try settle(browser, 50);
    try expectEval(page, "(history.length - before) + ' ' + history.state + ' ' + location.hash", "2 b2 #b2");
    try page.runScript("history.back();");
    try runUntil(browser, page, "String(location.hash === '#a')");
    try expectEval(page, "String(history.state)", "a");
}

test "pushState twice and replaceState in one task keep every entry, and back() lands on the first (whatwg/html#10232)" {
    try onFreshThread(twoPushesInOneTask);
}
