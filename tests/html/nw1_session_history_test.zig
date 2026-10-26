//! Session history pieces of lane newwin1's batch: the URL and history update
//! steps on an initial about:blank document (S4), each document's History
//! length and index (S1), and the entry a load finalizes before the document
//! it replaces unloads (S2).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");
const runtime = @import("runtime");

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

fn pushStateOnInitialAboutBlank() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe></iframe></body>", .{ .base_url = "http://example.test/top" });
    // The frame shows its initial about:blank document (an iframe with no
    // src is not navigated): URL and history update steps step 4 makes
    // pushState() a replaceState() there - its URL changes, the joint
    // session history's length does not
    // (html/browsers/browsing-the-web/navigating-across-documents/initial-empty-document/iframe-src-204-pushState-replaceState.html).
    try expectEval(page,
        \\const w = frames[0];
        \\const before = history.length;
        \\w.history.pushState({ n: 1 }, '', 'about:blank#foo');
        \\[history.length - before, w.history.length - before, w.location.href, w.history.state.n].join()
    , "0,0,about:blank#foo,1");
}

test "pushState on a frame's initial about:blank document replaces its entry" {
    try onFreshThread(pushStateOnInitialAboutBlank);
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

fn embedderLoadsMakeEntries() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    // A load from the initial about:blank document replaces its entry
    // ("the navigation must be a replace"); a load to another URL pushes one
    // (navigate step 13): the page's traversable keeps both.
    try page.loadHTML("<!doctype html><title>one</title><script>window.name += 'one,';</script>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    try expectEval(page, "String(history.length)", "1");
    try page.loadHTML("<!doctype html><title>two</title><script>window.name += 'two,';</script>", .{ .base_url = "http://example.test/two" });
    try until(browser, "document.readyState === 'complete'");
    try expectEval(page, "String(history.length)", "2");
    // Back: the traversal re-creates the first page from the markup its
    // embedder gave (its entry keeps it, as an iframe srcdoc entry keeps its
    // markup), at its URL - the embedder never served that URL.
    try page.runScript("history.back();");
    try until(browser, "document.URL === 'http://example.test/one' && document.readyState === 'complete'");
    try expectEval(page, "[document.title, window.name, history.length].join()", "one,one,two,one,,2");
    try page.runScript("history.forward();");
    try until(browser, "document.URL === 'http://example.test/two' && document.readyState === 'complete'");
    try expectEval(page, "[document.title, window.name].join()", "two,one,two,one,two,");
}

test "an embedder's loads push session history entries, and a traversal re-creates a page from its markup" {
    try onFreshThread(embedderLoadsMakeEntries);
}
