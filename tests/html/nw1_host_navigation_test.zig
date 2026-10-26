//! The host page navigated by its own script (lane newwin1, B5): the page's
//! top-level traversable runs HTML "navigate" as a popup's does - its
//! beforeunload, fetch and commit as tasks, the next document in a new Window
//! behind the same WindowProxy (create and initialize a Document object step
//! 7), its entry in the traversable's session history. Location's setters,
//! hyperlinks and forms that target the page, and javascript: URLs used to
//! stop at error.NotImplemented for the host page.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
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

fn locationNavigation() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    const traversable = page.traversable;
    // HTML "navigate" queues its work: nothing has changed when the setter
    // returns.
    try expectEval(page, "window.marker = 'page one'; location.href = 'about:blank'; document.URL", "http://example.test/one");
    try until(browser, "document.URL === 'about:blank' && document.readyState === 'complete'");
    // The same traversable, a new Window (the page left was no initial
    // about:blank document), and a second session history entry.
    try testing.expectEqual(traversable, page.traversable);
    try expectEval(page, "[typeof marker, history.length].join()", "undefined,2");
}

test "location.href on the host page navigates it, and the next document gets a new Window" {
    try onFreshThread(locationNavigation);
}

fn javascriptUrlDocument() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    // HTML "navigate to a javascript: URL": a String result is the new
    // document's markup, at the page's URL, in a new Window.
    try page.runScript("window.marker = 'page one'; location.href = 'javascript:\"<p id=js>from javascript</p>\"';");
    try until(browser, "document.getElementById('js') !== null");
    try expectEval(page, "[typeof marker, document.URL, document.getElementById('js').textContent].join()", "undefined,http://example.test/one,from javascript");
}

test "a javascript: URL whose result is a string replaces the host page's document" {
    try onFreshThread(javascriptUrlDocument);
}

fn embedderNavigatesInPlace() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title><script>window.name = 'kept';</script>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    const traversable = page.traversable;
    // The embedder's address bar: the same page, the same traversable.
    try browser.navigateInPlace("about:blank");
    try testing.expectEqual(page, browser.current_context.?);
    try until(browser, "document.URL === 'about:blank'");
    try testing.expectEqual(traversable, page.traversable);
    // A cross-origin top-level navigation clears the navigable target name
    // (finalize a cross-document navigation step 4); history kept its entry.
    try expectEval(page, "[history.length, JSON.stringify(window.name)].join()", "2,\"\"");
}

test "an embedder's in-place navigation keeps the page's traversable and its history" {
    try onFreshThread(embedderNavigatesInPlace);
}

fn fileUrlRefused() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    // A document that is not itself a file: document navigating the page to
    // a file: URL goes nowhere - the browsers refuse local resources to web
    // content - and the navigation API sees it aborted
    // (navigation-methods/return-value/navigate-file-url.html).
    try page.runScript(
        \\globalThis.outcome = 'pending';
        \\navigation.navigate('file://').committed.then(() => { outcome = 'committed'; }, (e) => { outcome = e.name; });
    );
    try until(browser, "outcome !== 'pending'");
    try expectEval(page, "[outcome, document.URL].join()", "AbortError,http://example.test/one");
}

test "the host page's navigation to a file: URL is refused and aborted" {
    try onFreshThread(fileUrlRefused);
}

fn stopCancelsPlannedFormNavigation() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title><form id=form action='about:blank'></form>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    // HTML "stop loading" in the task that planned the form's navigation:
    // the planned navigation is cancelled - Blink's FrameLoader::
    // StopAllLoaders calls CancelFormSubmission(); WebKit's stopAllLoaders
    // cancels the NavigationScheduler
    // (navigating-across-documents/form-submit-and-window-stop.html).
    try page.runScript("window.marker = 'kept'; document.getElementById('form').submit(); window.stop();");
    _ = try browser.runEventLoopBlocking(200);
    try expectEval(page, "[window.marker, document.URL].join()", "kept,http://example.test/one");
}

test "window.stop in the task that submitted a form cancels its planned navigation of the host page" {
    try onFreshThread(stopCancelsPlannedFormNavigation);
}
