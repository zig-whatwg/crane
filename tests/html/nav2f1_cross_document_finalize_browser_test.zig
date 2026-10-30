//! Lane nav2 F1, in a Browser: "finalize a cross-document navigation" and
//! its "apply the push/replace history step" are an item of the
//! traversable's session history traversal queue (navigate step 23.9's
//! completionSteps), so a cross-document commit waits for the items queued
//! before it:
//!
//! - a frame's commit behind another frame's running traversal lands after
//!   that traversal's popstate (today's inline commit landed first and
//!   settled the traversal);
//! - a later navigation of the navigable, started while the commit waits,
//!   does not cancel it: the navigation is mature and commits, as the spec's
//!   queued finalize never checks the ongoing navigation and as Chromium
//!   commits a request that is ready to commit (FrameTreeNode
//!   ::TakeNavigationRequest resets only one that is not) - then the later
//!   one commits after it;
//! - the host page's own navigation (Context.navigate, the embedder's
//!   address bar) commits through the queue too (lane nav2 F2);
//! - liveness (integrator's condition 2): a navigable removed while its
//!   commit waits, and a Browser that ends with a commit queued, leave the
//!   queue going and nothing behind.

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

/// A top-level page with two srcdoc frames, loaded; the first has pushed one
/// same-document entry (step 1), and `log` records what follows.
fn twoFramesFirstPushed(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>a</p>'></iframe><iframe srcdoc='<p>b</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'a' && frames[1].document.body?.textContent === 'b')");
    try page.runScript(
        \\frames[0].history.pushState(null, '', 'about:srcdoc#a1');
        \\globalThis.log = [];
        \\frames[0].onpopstate = () => log.push('A-popstate');
    );
    try settle(browser, 20);
    try expectEval(page, "history.length", "2");
    return page;
}

fn commitWaitsForTraversal() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFramesFirstPushed(browser);
    // The first frame's same-document traversal is appended first; the
    // second frame's srcdoc navigation answers at once, and its finalize is
    // appended behind it.
    try page.runScript(
        \\frames[0].history.back();
        \\document.querySelectorAll('iframe')[1].srcdoc = "<script>parent.log.push('B-commit')</script>";
    );
    try runUntil(browser, page, "String(log.length === 2)");
    try expectEval(page, "log.join()", "A-popstate,B-commit");
    // The traversal went back to step 0; the commit replaced the second
    // frame's entry in place (an about:srcdoc navigation at about:srcdoc:
    // navigate's URL-equals-the-active-document's rule),
    // so the first frame's forward entry stays.
    try expectEval(page, "[history.length, frames[0].location.hash].join()", "2,");
}

test "a frame's cross-document commit waits for the traversal queued before it: the traversal's popstate fires first" {
    try onFreshThread(commitWaitsForTraversal);
}

fn laterNavigationDoesNotCancelQueuedCommit() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFramesFirstPushed(browser);
    // While the second frame's first commit waits behind the traversal, the
    // popstate handler navigates that frame again.
    try page.runScript(
        \\frames[0].onpopstate = () => {
        \\  log.push('A-popstate');
        \\  document.querySelectorAll('iframe')[1].srcdoc = "<script>parent.log.push('B-late')</script>";
        \\};
        \\frames[0].history.back();
        \\document.querySelectorAll('iframe')[1].srcdoc = "<script>parent.log.push('B-commit')</script>";
    );
    try runUntil(browser, page, "String(log.length === 3)");
    try expectEval(page, "log.join()", "A-popstate,B-commit,B-late");
    try settle(browser, 50);
    try expectEval(page, "log.join()", "A-popstate,B-commit,B-late");
    // The later one's document is the one shown. Both replaced the frame's
    // entry - an about:srcdoc navigation of a document at about:srcdoc is a
    // "replace" (navigate: the URL equals the active document's URL) -
    // so the first frame's forward entry stays: two steps.
    try expectEval(page, "String(frames[1].document.documentElement.innerHTML.includes('B-late'))", "true");
    try expectEval(page, "history.length", "2");
}

test "a later navigation started while a commit waits on the queue does not cancel it: both commit, in order" {
    try onFreshThread(laterNavigationDoesNotCancelQueuedCommit);
}

fn hostNavigationGoesThroughQueue() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try runUntil(browser, page, "String(document.readyState === 'complete')");
    const bc = page.browsing_context orelse return error.NoBrowsingContext;
    const before: u64 = if (bc.getTop().traversal_queue) |queue| queue.next_token else 1;
    try browser.navigateInPlace("about:blank");
    try runUntil(browser, page, "String(document.URL === 'about:blank' && document.readyState === 'complete')");
    try settle(browser, 20);
    const queue = bc.getTop().traversal_queue orelse return error.NoQueue;
    // One item: the commit's finalize.
    try testing.expectEqual(before + 1, queue.next_token);
    try testing.expect(queue.running == null);
    try testing.expectEqual(@as(usize, 0), queue.items.items.len);
    try expectEval(page, "history.length", "2");
}

test "the host page's own navigation (Context.navigate) commits through its traversable's queue" {
    try onFreshThread(hostNavigationGoesThroughQueue);
}

fn frameRemovedWhileCommitQueued() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFramesFirstPushed(browser);
    // The second frame goes from the popstate handler, while its commit
    // waits behind the traversal.
    try page.runScript(
        \\frames[0].onpopstate = () => {
        \\  log.push('A-popstate');
        \\  document.querySelectorAll('iframe')[1].remove();
        \\};
        \\frames[0].history.back();
        \\document.querySelectorAll('iframe')[1].srcdoc = "<script>parent.log.push('B-commit')</script>";
    );
    try runUntil(browser, page, "String(log.length === 1 && frames.length === 1)");
    try settle(browser, 50);
    try expectEval(page, "log.join()", "A-popstate");
    // The queue went on: a later traversal still runs.
    try page.runScript("frames[0].history.pushState(null, '', 'about:srcdoc#a2'); frames[0].history.back();");
    try runUntil(browser, page, "String(log.length === 2)");
    const bc = page.browsing_context orelse return error.NoBrowsingContext;
    try settle(browser, 20);
    const queue = bc.getTop().traversal_queue orelse return error.NoQueue;
    try testing.expect(queue.running == null);
    try testing.expectEqual(@as(usize, 0), queue.items.items.len);
}

test "a frame removed while its commit waits on the queue: the commit ends and the queue goes on" {
    try onFreshThread(frameRemovedWhileCommitQueued);
}

fn browserEndsWithCommitQueued() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try twoFramesFirstPushed(browser);
    try page.runScript(
        \\frames[0].history.back();
        \\document.querySelectorAll('iframe')[1].srcdoc = "<script>parent.log.push('B-commit')</script>";
    );
    // One turn: the traversal runs and waits; the commit is queued behind it.
    _ = try browser.runEventLoopBlocking(1);
}

test "a Browser that ends with a commit queued frees it and its navigation" {
    try onFreshThread(browserEndsWithCommitQueued);
}
