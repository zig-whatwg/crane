//! HTML "navigate" step 24 runs "attempt to populate the history entry's
//! document" - its fetch - in parallel, and the navigation continues from a
//! task when the response is in (lane life1). A navigation to a URL that
//! needs no network - blob:, data:, file: - fetched it inside the call that
//! navigated (fetch_integration.fetchRequestNow / fetchNavigationResource),
//! so the caller waited for a file read or a blob copy. Chrome, Firefox and
//! Safari load each of these schemes asynchronously; now the fetch is the
//! navigation's own task's, and a blob: URL's entry is the one captured when
//! the navigation started (a URL revoked right after still loads).
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

fn loadedPage(browser: *browser_mod.Browser, markup: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    return page;
}

fn fileReadInParallel() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const url = try std.fmt.allocPrint(testing.allocator, "file://{s}/late.html", .{base});
    defer testing.allocator.free(url);

    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><title>one</title>");
    // The browser's own navigation (an address bar) to a file that is not
    // there yet: navigate returns before its fetch, which runs in parallel
    // (here, the navigation's task) - so the file written right after the
    // call is the one that loads. Read in the call, it was a 404.
    try browser.navigateInPlace(url);
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "late.html", .data = "<!doctype html><title>late</title>" });
    try until(browser, "document.URL.startsWith('file:') && document.readyState === 'complete'");
    try expectEval(page, "document.title", "late");
}

test "a file: navigation reads its file in parallel, not inside the call that navigates" {
    try onFreshThread(fileReadInParallel);
}

fn blobRevokedAfterNavigateLoads() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><body></body>");
    // File API: a blob URL parsed by the navigation holds its entry - the
    // fetch that now runs in parallel reads the entry captured when the
    // navigation started, not the store after the revoke
    // (FileAPI/url/url-in-tags-revoke.window.js).
    try page.runScript(
        \\const url = URL.createObjectURL(new Blob(['<!doctype html><title>from blob</title>'], {type: 'text/html'}));
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.append(frame);
        \\frame.src = url;
        \\URL.revokeObjectURL(url);
    );
    try until(browser, "!!frame.contentDocument && frame.contentDocument.title === 'from blob'");
    try expectEval(page, "frame.contentDocument.URL.startsWith('blob:http://example.test/')", "true");
}

test "a blob: URL revoked right after the navigation that names it still loads" {
    try onFreshThread(blobRevokedAfterNavigateLoads);
}

fn dataNavigationLoadsFromItsTask() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><body></body>");
    // Two data: navigations of one frame in one task: the first ends when
    // the second becomes the ongoing navigation (navigate step 19), before
    // its fetch - only the second's document is ever made.
    try page.runScript(
        \\globalThis.messages = [];
        \\addEventListener('message', (e) => messages.push(e.data));
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.append(frame);
        \\frame.src = "data:text/html,<script>parent.postMessage('first', '*')</script>";
        \\frame.src = "data:text/html,<script>parent.postMessage('second', '*')</script>";
    );
    try until(browser, "messages.length > 0");
    _ = try browser.runEventLoopBlocking(50);
    try expectEval(page, "messages.join()", "second");
}

test "a data: navigation superseded in its own task never makes its document" {
    try onFreshThread(dataNavigationLoadsFromItsTask);
}
