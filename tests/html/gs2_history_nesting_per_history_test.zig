//! HTML "shared history push/replace state steps" step 3, "optionally, throw
//! a SecurityError": Crane throws it for pushState()/replaceState() calls
//! nested 16 deep on one History - a navigate handler that pushes or replaces
//! from inside the event its own call fired recurses without end otherwise
//! (navigate-event/replaceState-inside-back-handler-infinite). The depth is
//! the History's own, as each navigable's rate limit is its own
//! (navigation_rate_limit_test.zig; Blink's NavigationRateLimiter is a
//! frame's): a parent's handler nested 16 deep still updates its frame's
//! history. It was a thread-local that every History on the thread shared.
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
    if (run.failure) |err| return err;
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

fn nestingIsPerHistory() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>f</p>'></iframe></body>", .{ .base_url = "http://example.test/top" });
    try runUntil(browser, page, "String(document.readyState === 'complete' && frames[0].document.body?.textContent === 'f')");
    try page.runScript(
        \\globalThis.depth = 0;
        \\globalThis.results = [];
        \\navigation.onnavigate = () => {
        \\  depth += 1;
        \\  if (depth < 16) { history.replaceState(null, ''); return; }
        \\  if (depth !== 16) return;
        \\  for (const h of [history, frames[0].history]) {
        \\    try { h.replaceState(null, ''); results.push('ok'); } catch (e) { results.push(e.name); }
        \\  }
        \\};
        \\history.replaceState(null, '');
    );
    // Sixteen nested calls on the page's History: the next on it is refused,
    // and its frame's History, nested in no call of its own, is not.
    try expectEval(page, "String(depth)", "16");
    try expectEval(page, "results.join()", "SecurityError,ok");
    // The depth unwound: the page's History takes a call again.
    try page.runScript("navigation.onnavigate = null; globalThis.after = 'none'; try { history.replaceState(null, ''); after = 'ok'; } catch (e) { after = e.name; }");
    try expectEval(page, "after", "ok");
}

test "a History's pushState/replaceState nesting limit is its own: a parent nested 16 deep still updates its frame's history" {
    try onFreshThread(nestingIsPerHistory);
}
