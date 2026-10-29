//! Lane nav2, piece D (integrator's condition on the per-navigable views,
//! 2026-10-28): while a frame's document is being left, its pagehide,
//! unload and pageswap handlers read the session history as that document
//! last saw it - history.length and navigation.currentEntry are still the
//! OLD values - because HTML updates a document's History and navigation API
//! only when the TARGET document becomes active ("update document for
//! history step application", which runs after "unload a document and its
//! descendants"). The views (joint_history View) must keep this when later
//! pieces move where they are written.

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
    return error.ConditionNeverMet;
}

/// Install, on the frame's current Window, pagehide, unload and pageswap
/// listeners that record what that Window's history.length and
/// navigation.currentEntry.id are when each fires, after recording them now.
const watch_frame =
    \\{
    \\  const w = frames[0];
    \\  globalThis.before = [w.history.length, w.navigation.currentEntry.id].join();
    \\  globalThis.seen = [];
    \\  for (const type of ['pageswap', 'pagehide', 'unload']) {
    \\    w.addEventListener(type, () => {
    \\      seen.push(type + ':' + [w.history.length, w.navigation.currentEntry.id].join());
    \\    });
    \\  }
    \\}
;

/// Every recorded event saw the values recorded before the navigation.
const all_old = "seen.length === 3 && seen.every(s => s.endsWith(':' + before)) ? 'old' : JSON.stringify([before, seen])";

fn crossDocumentNavigation() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>one</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'one')");
    try page.runScript(watch_frame);
    // A push to a new document (a URL other than the frame's: not a replace).
    try page.runScript("frames[0].location.href = 'about:blank?two';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?two' && frames[0].document.readyState === 'complete')");
    try expectEval(page, all_old, "old");
    // The new document reads the pushed entry: one more step, a new entry.
    try expectEval(page, "String(frames[0].history.length === Number(before.split(',')[0]) + 1 && frames[0].navigation.currentEntry.id !== before.split(',')[1])", "true");
}

test "a frame's document left by a cross-document navigation reads its old history length and current entry in pageswap, pagehide and unload" {
    try onFreshThread(crossDocumentNavigation);
}

fn crossDocumentTraversal() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>one</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'one')");
    try page.runScript("frames[0].location.href = 'about:blank?two';");
    try runUntil(browser, page, "String(frames[0].location.href === 'about:blank?two' && frames[0].document.readyState === 'complete')");
    try page.runScript(watch_frame);
    // Back to the first document: a traversal that repopulates its entry.
    try page.runScript("frames[0].history.back();");
    try runUntil(browser, page, "String(frames[0].document.body?.textContent === 'one')");
    try expectEval(page, all_old, "old");
}

test "a frame's document left by a cross-document traversal reads its old history length and current entry in pageswap, pagehide and unload" {
    try onFreshThread(crossDocumentTraversal);
}
